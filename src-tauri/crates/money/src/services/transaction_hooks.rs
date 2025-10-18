use std::str::FromStr;

use common::{
    BusinessCode,
    crud::hooks::Hooks,
    error::{AppError, MijiResult},
    utils::date::DateUtils,
};
use sea_orm::{
    ActiveModelTrait, ColumnTrait, DatabaseTransaction, EntityTrait, IntoActiveModel, QueryFilter,
    QuerySelect,
    prelude::{DateTimeWithTimeZone, Decimal, async_trait::async_trait},
};
use snafu::GenerateImplicitData;

use crate::{
    dto::{
        account::AccountType,
        installment::InstallmentPlanCreate,
        transactions::{
            CreateTransactionRequest, PaymentMethod, TransactionStatus, TransactionType,
            UpdateTransactionRequest,
        },
    },
    error::MoneyError,
    services::installment::get_installment_service,
};

#[derive(Debug)]
pub struct NoOpHooks;

#[async_trait]
impl Hooks<entity::transactions::Entity, CreateTransactionRequest, UpdateTransactionRequest>
    for NoOpHooks
{
    async fn before_create(
        &self,
        tx: &DatabaseTransaction,
        data: &CreateTransactionRequest,
    ) -> MijiResult<()> {
        // 验证账户存在
        let account = verify_account_exists(tx, &data.account_serial_num).await?;

        // 检查支出交易的余额
        if data.transaction_type == TransactionType::Expense && data.amount > account.balance {
            return Err(MoneyError::InsufficientFunds {
                balance: data.amount,
                backtrace: snafu::Backtrace::generate(),
            }
            .into());
        }
        Ok(())
    }

    async fn after_create(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::transactions::Model,
    ) -> MijiResult<()> {
        if model.is_installment.unwrap() {
            let installment_plan_request = InstallmentPlanCreate {
                serial_num: model.installment_plan_serial_num.clone().unwrap(),
                transaction_serial_num: model.serial_num.clone(),
                account_serial_num: model.account_serial_num.clone(),
                total_amount: model.installment_amount.unwrap(),
                total_periods: model.total_periods.unwrap(),
                installment_amount: model.installment_amount.unwrap(),
                first_due_date: model.first_due_date.unwrap(),
            };
            let installment_service = get_installment_service();
            installment_service
                .create_installment_plan_with_details(tx, installment_plan_request)
                .await?;

            // 检查是否需要立即处理第1期分期记账
            if should_process_first_installment_immediately(model)
                && let Err(e) = process_first_installment_immediately(tx, model).await
            {
                // 立即记账失败，记录错误但不回滚整个事务
                // 让定时任务稍后重试
                tracing::warn!("立即处理第1期分期记账失败，将由定时任务重试: {}", e);
            }
        } else {
            // Only not transfer
            if model.category != "Transfer" {
                let transaction_type = TransactionType::from_str(&model.transaction_type)?;
                update_account_balance(
                    tx,
                    &model.account_serial_num,
                    transaction_type,
                    model.amount,
                    false,
                )
                .await?;
            }
            if model.transaction_type == "Expense" {
                update_budget_used(
                    tx,
                    &model.account_serial_num,
                    model.date,
                    model.amount,
                    true,
                )
                .await?;
            }
        }
        Ok(())
    }

    async fn before_update(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::transactions::Model,
        data: &UpdateTransactionRequest,
    ) -> MijiResult<()> {
        if model.is_deleted {
            return Err(AppError::simple(
                BusinessCode::MoneyInsufficientFunds,
                "无法更新已删除的交易",
            ));
        }
        if let Some(new_status) = &data.transaction_status {
            let current_status = TransactionStatus::from_str(&model.transaction_status)?;
            if current_status == TransactionStatus::Completed
                && new_status != &TransactionStatus::Completed
            {
                return Err(AppError::simple(
                    BusinessCode::MoneyTransactionDeclined,
                    "无法更改已完成交易的状态",
                ));
            }
        }
        if let Some(account_serial_num) = &data.account_serial_num {
            verify_account_exists(tx, account_serial_num).await?;
        }
        Ok(())
    }

    async fn after_update(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::transactions::Model,
    ) -> MijiResult<()> {
        if model.category != "Transfer" {
            let transaction_type = TransactionType::from_str(&model.transaction_type)?;
            let delta = model.amount - model.refund_amount;

            if transaction_type == TransactionType::Expense {
                update_budget_used(
                    tx,
                    &model.account_serial_num,
                    model.date,
                    delta.abs(),
                    delta > Decimal::ZERO,
                )
                .await?;
            }

            update_account_balance(
                tx,
                &model.account_serial_num,
                transaction_type,
                delta.abs(),
                delta < Decimal::ZERO,
            )
            .await?;
        }

        // 同步更新已记账的分期交易
        sync_installment_transactions(tx, model).await?;

        Ok(())
    }

    async fn before_delete(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::transactions::Model,
    ) -> MijiResult<()> {
        if model.category == "Transfer"
            && let Some(related_id) = &model.related_transaction_serial_num
        {
            let related_transaction = entity::transactions::Entity::find_by_id(related_id)
                .one(tx)
                .await?
                .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "关联交易不存在"))?;
            if !related_transaction.is_deleted {
                return Err(AppError::simple(
                    BusinessCode::MoneyTransactionDeclined,
                    "无法删除转账交易，需先删除关联交易",
                ));
            }
        }
        if model.transaction_type == "Expense" {
            update_budget_used(
                tx,
                &model.account_serial_num,
                model.date,
                model.amount,
                false,
            )
            .await?;
        }

        Ok(())
    }

    async fn after_delete(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::transactions::Model,
    ) -> MijiResult<()> {
        if model.category != "Transfer" {
            let transaction_type = TransactionType::from_str(&model.transaction_type)?;
            update_account_balance(
                tx,
                &model.account_serial_num,
                transaction_type,
                model.amount,
                true,
            )
            .await?;
        }

        if model.category == "Transfer"
            && let Some(related_id) = &model.related_transaction_serial_num
        {
            let mut related_active = entity::transactions::Entity::find_by_id(related_id)
                .one(tx)
                .await?
                .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "关联交易不存在"))?
                .into_active_model();
            related_active.is_deleted = sea_orm::ActiveValue::Set(true);
            related_active.update(tx).await?;
        }
        Ok(())
    }
}

async fn verify_account_exists(
    tx: &DatabaseTransaction,
    account_serial_num: &str,
) -> MijiResult<entity::account::Model> {
    entity::account::Entity::find_by_id(account_serial_num)
        .one(tx)
        .await?
        .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "账户不存在"))
}

/// 更新账户余额
///
/// 根据交易类型（Income/Expense）以及是否为回滚操作，计算新的账户余额并更新到数据库。
///
/// 参数说明：
/// - `tx`: 数据库事务对象，用于执行更新操作
/// - `account_serial_num`: 要更新余额的账户编号
/// - `transaction_type`: 交易类型（Income/Expense/Transfer）
/// - `amount`: 交易金额
/// - `is_rollback`: 是否为回滚操作
pub async fn update_account_balance(
    tx: &DatabaseTransaction,
    account_serial_num: &str,
    transaction_type: TransactionType,
    amount: Decimal,
    is_rollback: bool,
) -> MijiResult<()> {
    // 查询账户并加锁，防止并发修改
    let account = entity::account::Entity::find_by_id(account_serial_num)
        .lock_exclusive() // 数据库行级锁，保证操作原子性
        .one(tx)
        .await?
        .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "账户不存在"))?;

    // 根据交易类型和是否回滚计算新的余额
    let new_balance = match transaction_type {
        TransactionType::Income => {
            if is_rollback {
                // 回滚收入：原来增加的金额现在需要扣除
                account.balance - amount
            } else {
                // 正常收入：增加账户余额
                account.balance + amount
            }
        }
        TransactionType::Expense => {
            if is_rollback {
                // 回滚支出：原来扣除的金额现在需要增加回来
                account.balance + amount
            } else {
                // 正常支出：减少账户余额
                account.balance - amount
            }
        }
        TransactionType::Transfer => {
            // 转账交易不在此函数处理，直接报错
            return Err(AppError::simple(
                BusinessCode::MoneyTransferLimitExceeded,
                "转账交易不应在此更新余额",
            ));
        }
    };

    // 将查询到的账户转换为可更新模型
    let mut account_active = account.into_active_model();
    // 设置新的余额
    account_active.balance = sea_orm::ActiveValue::Set(new_balance);
    // 执行更新操作
    account_active.update(tx).await?;

    Ok(())
}

async fn update_budget_used(
    tx: &DatabaseTransaction,
    account_serial_num: &str,
    transaction_date: DateTimeWithTimeZone,
    amount: Decimal,
    is_add: bool,
) -> MijiResult<()> {
    let budgets = entity::budget::Entity::find()
        .filter(entity::budget::Column::AccountSerialNum.eq(account_serial_num))
        .filter(entity::budget::Column::IsActive.eq(true))
        .filter(entity::budget::Column::StartDate.lte(transaction_date))
        .filter(entity::budget::Column::EndDate.gte(transaction_date))
        .all(tx)
        .await?;
    if budgets.is_empty() {
        return Ok(());
    }
    for budget in budgets.into_iter() {
        let new_used = if is_add {
            budget.used_amount + amount
        } else {
            budget.used_amount - amount
        };

        // 更新当前周期使用金额
        let mut new_current_period_used = budget.current_period_used;
        if is_add {
            new_current_period_used += amount;
        } else {
            new_current_period_used -= amount;
        }

        // 更新进度百分比
        let new_progress = if budget.amount.is_zero() {
            Decimal::ZERO
        } else {
            ((new_current_period_used / budget.amount) * Decimal::from(100)).round_dp(2)
        };

        let mut budget_active = budget.into_active_model();
        budget_active.used_amount = sea_orm::ActiveValue::Set(new_used);
        budget_active.current_period_used = sea_orm::ActiveValue::Set(new_current_period_used);
        budget_active.progress = sea_orm::ActiveValue::Set(new_progress);
        budget_active.updated_at = sea_orm::ActiveValue::Set(Some(DateUtils::local_now()));
        budget_active.update(tx).await?;
    }
    Ok(())
}

/// 同步更新已记账的分期交易
///
/// 当原交易的支付渠道、分类、子分类发生变化时，同步更新所有已记账的分期交易
async fn sync_installment_transactions(
    tx: &DatabaseTransaction,
    parent_model: &entity::transactions::Model,
) -> MijiResult<()> {
    // 查找所有已记账的分期交易
    let installment_transactions = entity::transactions::Entity::find()
        .filter(
            entity::transactions::Column::RelatedTransactionSerialNum.eq(&parent_model.serial_num),
        )
        .filter(entity::transactions::Column::IsDeleted.eq(false))
        .filter(entity::transactions::Column::TransactionStatus.eq("Completed"))
        .all(tx)
        .await?;

    if installment_transactions.is_empty() {
        return Ok(());
    }

    // 更新每个已记账的分期交易
    for installment_transaction in installment_transactions {
        let mut installment_active = installment_transaction.into_active_model();

        // 同步支付渠道
        installment_active.payment_method =
            sea_orm::ActiveValue::Set(parent_model.payment_method.clone());

        // 同步分类
        installment_active.category = sea_orm::ActiveValue::Set(parent_model.category.clone());

        // 同步子分类
        installment_active.sub_category =
            sea_orm::ActiveValue::Set(parent_model.sub_category.clone());

        // 更新修改时间
        installment_active.updated_at = sea_orm::ActiveValue::Set(Some(DateUtils::local_now()));

        // 执行更新
        installment_active.update(tx).await?;
    }

    Ok(())
}

/// 判断是否需要立即处理第1期分期记账
fn should_process_first_installment_immediately(model: &entity::transactions::Model) -> bool {
    // 检查首期还款日期是否为今天
    if let Some(first_due_date) = model.first_due_date {
        let today = DateUtils::local_now_naivedate();
        return first_due_date == today;
    }
    false
}

/// 立即处理第1期分期记账
async fn process_first_installment_immediately(
    tx: &DatabaseTransaction,
    model: &entity::transactions::Model,
) -> MijiResult<()> {
    let now = DateUtils::local_now();
    let paid_date_now = DateUtils::local_now_naivedate();

    // 1. 查找第1期分期明细
    let first_period_detail = entity::installment_details::Entity::find()
        .filter(
            entity::installment_details::Column::PlanSerialNum
                .eq(model.installment_plan_serial_num.clone().unwrap()),
        )
        .filter(entity::installment_details::Column::PeriodNumber.eq(1))
        .filter(entity::installment_details::Column::Status.eq("PENDING"))
        .one(tx)
        .await?
        .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "第1期分期明细不存在"))?;

    // 2. 创建第1期支出交易记录
    let expense_transaction = crate::dto::transactions::CreateTransactionRequest {
        transaction_type: TransactionType::Expense,
        transaction_status: TransactionStatus::Completed,
        date: now,
        amount: first_period_detail.amount,
        currency: model.currency.clone(),
        description: format!("分期付款第1期 - {}", model.description),
        notes: Some(format!(
            "分期计划: {}, 第1/{}期",
            model.installment_plan_serial_num.as_ref().unwrap(),
            model.total_periods.unwrap()
        )),
        account_serial_num: first_period_detail.account_serial_num.clone(),
        to_account_serial_num: None,
        category: model.category.clone(),
        sub_category: model.sub_category.clone(),
        tags: None,
        split_members: None,
        payment_method: PaymentMethod::from_str(&model.payment_method).map_err(|e| {
            AppError::simple(
                BusinessCode::InvalidParameter,
                format!("无效的支付方式: {e}"),
            )
        })?,
        actual_payer_account: AccountType::from_str(&model.actual_payer_account).map_err(|e| {
            AppError::simple(
                BusinessCode::InvalidParameter,
                format!("无效的账户类型: {e}"),
            )
        })?,
        related_transaction_serial_num: Some(model.serial_num.clone()),
        is_installment: Some(false),
        first_due_date: None,
        total_periods: None,
        remaining_periods_amount: None,
        remaining_periods: None,
        installment_amount: None,
    };

    // 3. 手动调用 before_create hooks
    let hooks = NoOpHooks;
    hooks.before_create(tx, &expense_transaction).await?;

    // 4. 创建交易记录
    let transaction_model: entity::transactions::ActiveModel = expense_transaction.try_into()?;
    let created_transaction = transaction_model.insert(tx).await?;

    // 5. 手动调用 after_create hooks（更新账户余额）
    hooks.after_create(tx, &created_transaction).await?;

    // 6. 更新分期明细状态为已支付
    let mut detail_active = first_period_detail.clone().into_active_model();
    detail_active.status = sea_orm::ActiveValue::Set("PAID".to_string());
    detail_active.paid_date = sea_orm::ActiveValue::Set(Some(paid_date_now));
    detail_active.paid_amount = sea_orm::ActiveValue::Set(Some(first_period_detail.amount));
    detail_active.updated_at = sea_orm::ActiveValue::Set(Some(now));
    detail_active.update(tx).await?;

    // 7. 更新主交易记录的剩余期数和金额
    let mut transaction_active = model.clone().into_active_model();
    let current_remaining = model
        .remaining_periods
        .unwrap_or(model.total_periods.unwrap());
    let new_remaining = current_remaining - 1;
    let current_remaining_amount = model
        .remaining_periods_amount
        .unwrap_or(model.installment_amount.unwrap());
    let new_remaining_amount = current_remaining_amount - first_period_detail.amount;

    transaction_active.remaining_periods = sea_orm::ActiveValue::Set(Some(new_remaining));
    transaction_active.remaining_periods_amount =
        sea_orm::ActiveValue::Set(Some(new_remaining_amount));
    transaction_active.updated_at = sea_orm::ActiveValue::Set(Some(now));

    // 8. 检查是否为最后一期
    if new_remaining == 0 {
        // 更新交易状态为已完成
        transaction_active.transaction_status = sea_orm::ActiveValue::Set("Completed".to_string());
    }

    transaction_active.update(tx).await?;

    tracing::info!(
        "成功立即处理第1期分期记账，交易序列号: {}",
        model.serial_num
    );
    Ok(())
}
