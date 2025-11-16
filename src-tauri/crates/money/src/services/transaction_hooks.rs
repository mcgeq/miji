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
    services::installment::InstallmentService,
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
        // 注意：这里无法直接访问原始的 CreateTransactionRequest 数据
        // family_ledger_serial_num 需要在调用层面处理
        
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
            let installment_service = InstallmentService::default();
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
        // 同步家庭记账本统计数据
        sync_family_ledger_after_create(tx, model).await?;
        
        // TODO: split_records 创建需要从原始请求中获取 split_members 数据
        // 由于 after_create hook 无法访问 CreateTransactionRequest，
        // split_records 的创建需要在调用层面手动处理
        // 参考: transaction service 中创建交易后手动调用 create_split_records
        
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
        // 检查是否为转账交易
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

        if !model.is_installment.unwrap_or(false) && model.related_transaction_serial_num.is_some()
        {
            return Err(AppError::simple(
                BusinessCode::MoneyTransactionDeclined,
                "分期交易不支持直接删除，请删除主交易",
            ));
        }

        // 检查是否为主分期交易（有分期计划）
        if let Some(installment_plan_serial_num) = &model.installment_plan_serial_num {
            // 检查分期状态并处理删除逻辑
            handle_installment_transaction_deletion(tx, model, installment_plan_serial_num).await?;
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
        // 检查是否为分期主交易
        let is_installment_main =
            model.is_installment.unwrap_or(false) && model.installment_plan_serial_num.is_some();

        // 对于分期主交易，需要检查是否有已记账的分期
        let should_update_balance = if is_installment_main {
            // 检查是否有已记账的分期
            if let Some(installment_plan_serial_num) = &model.installment_plan_serial_num {
                let details = entity::installment_details::Entity::find()
                    .filter(
                        entity::installment_details::Column::PlanSerialNum
                            .eq(installment_plan_serial_num),
                    )
                    .all(tx)
                    .await?;

                let paid_details: Vec<_> = details
                    .iter()
                    .filter(|detail| detail.status == "PAID")
                    .collect();

                // 只有场景3（所有分期都记账完成）才需要更新账户余额
                !paid_details.is_empty() && details.len() == paid_details.len()
            } else {
                false
            }
        } else {
            // 非分期交易，正常更新账户余额
            model.category != "Transfer"
        };

        if should_update_balance {
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

        // 处理分期交易删除后的清理工作
        if let Some(installment_plan_serial_num) = &model.installment_plan_serial_num {
            cleanup_installment_after_deletion(tx, model, installment_plan_serial_num).await?;
        }

        // 同步家庭记账本统计数据
        sync_family_ledger_after_delete(tx, model).await?;

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

/// 创建交易后同步家庭记账本统计数据
async fn sync_family_ledger_after_create(
    tx: &DatabaseTransaction,
    transaction: &entity::transactions::Model,
) -> MijiResult<()> {
    // 查找关联的家庭记账本
    let associations = entity::family_ledger_transaction::Entity::find()
        .filter(entity::family_ledger_transaction::Column::TransactionSerialNum.eq(&transaction.serial_num))
        .all(tx)
        .await?;
    
    if associations.is_empty() {
        return Ok(());
    }
    
    for association in associations {
        // 获取记账本
        let ledger = entity::family_ledger::Entity::find_by_id(&association.family_ledger_serial_num)
            .one(tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "家庭记账本不存在"))?;
        
        let mut ledger_active = ledger.clone().into_active_model();
        
        // 1. 更新交易数量
        let current_transactions = ledger.transactions;
        ledger_active.transactions = sea_orm::ActiveValue::Set(current_transactions + 1);
        
        // 2. 更新收入/支出统计 - TODO: 需要添加数据库字段
        // let transaction_type = TransactionType::from_str(&transaction.transaction_type)?;
        // match transaction_type {
        //     TransactionType::Income => {
        //         // total_income += transaction.amount
        //     }
        //     TransactionType::Expense => {
        //         // total_expense += transaction.amount
        //     }
        //     TransactionType::Transfer => {}
        // }
        
        // 3. 更新时间戳
        ledger_active.updated_at = sea_orm::ActiveValue::Set(Some(DateUtils::local_now()));
        
        // 4. 保存更新
        ledger_active.update(tx).await?;
        
        tracing::info!(
            "同步家庭记账本统计成功: ledger={}, transaction={}",
            association.family_ledger_serial_num,
            transaction.serial_num
        );
    }
    
    Ok(())
}

/// 删除交易后同步家庭记账本统计数据
async fn sync_family_ledger_after_delete(
    tx: &DatabaseTransaction,
    transaction: &entity::transactions::Model,
) -> MijiResult<()> {
    // 查找关联的家庭记账本
    let associations = entity::family_ledger_transaction::Entity::find()
        .filter(entity::family_ledger_transaction::Column::TransactionSerialNum.eq(&transaction.serial_num))
        .all(tx)
        .await?;
    
    if associations.is_empty() {
        return Ok(());
    }
    
    for association in associations {
        // 获取记账本
        let ledger = entity::family_ledger::Entity::find_by_id(&association.family_ledger_serial_num)
            .one(tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "家庭记账本不存在"))?;
        
        let mut ledger_active = ledger.clone().into_active_model();
        
        // 1. 减少交易数量
        let current_transactions = ledger.transactions;
        ledger_active.transactions = sea_orm::ActiveValue::Set((current_transactions - 1).max(0));
        
        // 2. 减去收入/支出统计 - TODO: 需要添加数据库字段
        // let transaction_type = TransactionType::from_str(&transaction.transaction_type)?;
        // match transaction_type {
        //     TransactionType::Income => {
        //         // total_income -= transaction.amount (max 0)
        //     }
        //     TransactionType::Expense => {
        //         // total_expense -= transaction.amount (max 0)
        //     }
        //     TransactionType::Transfer => {}
        // }
        
        // 3. 更新时间戳
        ledger_active.updated_at = sea_orm::ActiveValue::Set(Some(DateUtils::local_now()));
        
        // 4. 保存更新
        ledger_active.update(tx).await?;
        
        tracing::info!(
            "同步家庭记账本统计(删除)成功: ledger={}, transaction={}",
            association.family_ledger_serial_num,
            transaction.serial_num
        );
    }
    
    Ok(())
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
        family_ledger_serial_nums: None,
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

/// 处理分期交易删除前的检查和处理逻辑
async fn handle_installment_transaction_deletion(
    tx: &DatabaseTransaction,
    model: &entity::transactions::Model,
    installment_plan_serial_num: &str,
) -> MijiResult<()> {
    // 1. 获取分期计划
    let _plan = entity::installment_plans::Entity::find_by_id(installment_plan_serial_num)
        .one(tx)
        .await?
        .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "分期计划不存在"))?;

    // 2. 获取所有分期明细
    let details = entity::installment_details::Entity::find()
        .filter(entity::installment_details::Column::PlanSerialNum.eq(installment_plan_serial_num))
        .all(tx)
        .await?;

    // 3. 检查分期状态
    let paid_details: Vec<_> = details
        .iter()
        .filter(|detail| detail.status == "PAID")
        .collect();

    let pending_details: Vec<_> = details
        .iter()
        .filter(|detail| detail.status == "PENDING")
        .collect();

    // 4. 根据分期状态处理不同场景
    if paid_details.is_empty() {
        // 场景1：分期还没有记账
        tracing::info!("分期交易删除场景1：分期还没有记账，直接删除分期计划和明细");
        // 删除分期明细
        for detail in &details {
            entity::installment_details::Entity::delete_by_id(&detail.serial_num)
                .exec(tx)
                .await?;
        }
        // 删除分期计划
        entity::installment_plans::Entity::delete_by_id(installment_plan_serial_num)
            .exec(tx)
            .await?;
    } else if pending_details.is_empty() {
        // 场景3：所有分期都记账完成
        tracing::info!("分期交易删除场景3：所有分期都记账完成，标记主交易为删除并创建反向交易");
        // 这里不需要额外处理，主交易会被标记为删除
        // 反向交易会在after_delete中处理
    } else {
        // 场景2：分期已记账但未完成
        tracing::info!("分期交易删除场景2：分期已记账但未完成，删除已记账的分期交易和分期计划");

        // 删除已记账的分期交易
        let installment_transactions = entity::transactions::Entity::find()
            .filter(entity::transactions::Column::RelatedTransactionSerialNum.eq(&model.serial_num))
            .filter(entity::transactions::Column::IsDeleted.eq(false))
            .filter(entity::transactions::Column::TransactionStatus.eq("Completed"))
            .all(tx)
            .await?;

        for installment_tx in installment_transactions {
            // 保存需要的字段值
            let account_serial_num = installment_tx.account_serial_num.clone();
            let transaction_type_str = installment_tx.transaction_type.clone();
            let amount = installment_tx.amount;

            // 标记分期交易为删除
            let mut installment_active = installment_tx.into_active_model();
            installment_active.is_deleted = sea_orm::ActiveValue::Set(true);
            installment_active.updated_at = sea_orm::ActiveValue::Set(Some(DateUtils::local_now()));
            installment_active.update(tx).await?;

            // 反向更新账户余额（入账）
            let transaction_type = TransactionType::from_str(&transaction_type_str)?;
            update_account_balance(
                tx,
                &account_serial_num,
                transaction_type,
                amount,
                true, // 反向操作
            )
            .await?;
        }

        // 删除所有分期明细和分期计划
        for detail in &details {
            entity::installment_details::Entity::delete_by_id(&detail.serial_num)
                .exec(tx)
                .await?;
        }
        entity::installment_plans::Entity::delete_by_id(installment_plan_serial_num)
            .exec(tx)
            .await?;
    }

    Ok(())
}

/// 处理分期交易删除后的清理工作
async fn cleanup_installment_after_deletion(
    tx: &DatabaseTransaction,
    model: &entity::transactions::Model,
    installment_plan_serial_num: &str,
) -> MijiResult<()> {
    // 获取分期计划
    let plan = entity::installment_plans::Entity::find_by_id(installment_plan_serial_num)
        .one(tx)
        .await?;

    if plan.is_none() {
        // 分期计划已被删除，说明是场景1或场景2
        return Ok(());
    }

    // 获取所有分期明细
    let details = entity::installment_details::Entity::find()
        .filter(entity::installment_details::Column::PlanSerialNum.eq(installment_plan_serial_num))
        .all(tx)
        .await?;

    let paid_details: Vec<_> = details
        .iter()
        .filter(|detail| detail.status == "PAID")
        .collect();

    // 场景3：所有分期都记账完成，需要创建反向交易
    if !paid_details.is_empty() && details.len() == paid_details.len() {
        tracing::info!("分期交易删除场景3：创建反向交易");

        // 创建反向交易（入账）
        let reverse_transaction = CreateTransactionRequest {
            transaction_type: TransactionType::Income, // 反向入账
            transaction_status: TransactionStatus::Completed,
            date: DateUtils::local_now(),
            amount: model.amount,
            currency: model.currency.clone(),
            description: format!("分期交易删除反向入账 - {}", model.description),
            notes: Some(format!(
                "原分期交易: {}, 分期计划: {}",
                model.serial_num, installment_plan_serial_num
            )),
            account_serial_num: model.account_serial_num.clone(),
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
            actual_payer_account: AccountType::from_str(&model.actual_payer_account).map_err(
                |e| {
                    AppError::simple(
                        BusinessCode::InvalidParameter,
                        format!("无效的账户类型: {e}"),
                    )
                },
            )?,
            related_transaction_serial_num: Some(model.serial_num.clone()),
            is_installment: Some(false),
            first_due_date: None,
            total_periods: None,
            remaining_periods_amount: None,
            remaining_periods: None,
            installment_amount: None,
            family_ledger_serial_nums: None,
        };

        // 手动调用 before_create hooks
        let hooks = NoOpHooks;
        hooks.before_create(tx, &reverse_transaction).await?;

        // 创建反向交易记录
        let transaction_model: entity::transactions::ActiveModel =
            reverse_transaction.try_into()?;
        let created_transaction = transaction_model.insert(tx).await?;

        // 手动调用 after_create hooks（更新账户余额）
        hooks.after_create(tx, &created_transaction).await?;

        tracing::info!(
            "成功创建分期交易删除的反向交易: {}",
            created_transaction.serial_num
        );
    }

    Ok(())
}

/// 从交易的 split_members JSON 创建 split_records 记录
/// 
/// TODO: 需要重构此函数
/// 由于 split_members 字段已从 entity 中删除，此函数暂时禁用
/// 需要在调用层面手动处理，从 CreateTransactionRequest 中获取 split_members 数据
/// 
/// 逻辑：
/// 1. 查询交易关联的所有家庭账本
/// 2. 从请求参数获取 split_members 数据（不再从 entity 读取）
/// 3. 为每个账本和每个成员创建 split_records 记录
#[allow(dead_code)]
async fn create_split_records_from_transaction(
    tx: &DatabaseTransaction,
    transaction: &entity::transactions::Model,
    split_members_data: Option<Vec<serde_json::Value>>, // 新增参数
) -> MijiResult<()> {
    // 1. 查询交易关联的家庭账本
    let associations = entity::family_ledger_transaction::Entity::find()
        .filter(entity::family_ledger_transaction::Column::TransactionSerialNum.eq(&transaction.serial_num))
        .all(tx)
        .await?;
    
    if associations.is_empty() {
        tracing::debug!("交易 {} 没有关联账本，跳过创建分摊记录", transaction.serial_num);
        return Ok(());
    }
    
    // 2. 使用传入的 split_members 数据
    let split_members = match split_members_data {
        Some(members) if !members.is_empty() => members,
        _ => {
            tracing::debug!("交易 {} 没有分摊成员，跳过创建分摊记录", transaction.serial_num);
            return Ok(());
        }
    };
    
    // 3. 为每个账本和每个成员创建 split_records
    for association in associations {
        let family_ledger_serial_num = &association.family_ledger_serial_num;
        
        // 平均分摊金额（简化版本，后续可以支持更复杂的分摊规则）
        let split_amount = transaction.amount / Decimal::from(split_members.len() as i64);
        let split_percentage = Decimal::from(100) / Decimal::from(split_members.len() as i64);
        
        for split_member in &split_members {
            // 提取成员 serial_num
            let member_serial_num = match split_member.get("serialNum")
                .or_else(|| split_member.get("serial_num"))
                .and_then(|v| v.as_str()) 
            {
                Some(serial) => serial.to_string(),
                None => {
                    tracing::warn!("split_member 缺少 serialNum 字段: {:?}", split_member);
                    continue;
                }
            };
            
            // 生成 split_record 的 serial_num
            let split_record_serial_num = common::utils::uuid::McgUuid::uuid(38);
            
            // 提取自定义金额和付款人信息
            let custom_amount = split_member.get("amount")
                .and_then(|v| v.as_f64())
                .map(|a| Decimal::from_f64_retain(a).unwrap_or(split_amount));
            
            let payer_serial = split_member.get("payerSerialNum")
                .or_else(|| split_member.get("payer_serial_num"))
                .and_then(|v| v.as_str())
                .map(|s| s.to_string())
                .unwrap_or_else(|| member_serial_num.clone());
            
            let final_split_amount = custom_amount.unwrap_or(split_amount);
            
            // 保存用于日志的值（因为 insert 会移动所有权）
            let payer_for_log = payer_serial.clone();
            
            // 创建 split_record（区分付款人和欠款人）
            let split_record = entity::split_records::ActiveModel {
                serial_num: sea_orm::ActiveValue::Set(split_record_serial_num),
                transaction_serial_num: sea_orm::ActiveValue::Set(transaction.serial_num.clone()),
                family_ledger_serial_num: sea_orm::ActiveValue::Set(family_ledger_serial_num.clone()),
                split_rule_serial_num: sea_orm::ActiveValue::Set(None),
                payer_member_serial_num: sea_orm::ActiveValue::Set(payer_serial),
                owe_member_serial_num: sea_orm::ActiveValue::Set(member_serial_num.clone()),
                total_amount: sea_orm::ActiveValue::Set(transaction.amount),
                split_amount: sea_orm::ActiveValue::Set(final_split_amount),
                split_percentage: sea_orm::ActiveValue::Set(Some(split_percentage)),
                currency: sea_orm::ActiveValue::Set(transaction.currency.clone()),
                status: sea_orm::ActiveValue::Set("Confirmed".to_string()),
                split_type: sea_orm::ActiveValue::Set("Equal".to_string()),
                description: sea_orm::ActiveValue::Set(Some(transaction.description.clone())),
                notes: sea_orm::ActiveValue::Set(transaction.notes.clone()),
                confirmed_at: sea_orm::ActiveValue::Set(Some(DateUtils::local_now())),
                paid_at: sea_orm::ActiveValue::Set(None),
                due_date: sea_orm::ActiveValue::Set(None),
                reminder_sent: sea_orm::ActiveValue::Set(false),
                last_reminder_at: sea_orm::ActiveValue::Set(None),
                created_at: sea_orm::ActiveValue::Set(DateUtils::local_now()),
                updated_at: sea_orm::ActiveValue::Set(None),
            };
            
            // 插入数据库
            match split_record.insert(tx).await {
                Ok(_) => {
                    tracing::info!(
                        "成功创建分摊记录: transaction={}, ledger={}, payer={}, owe={}, amount={}",
                        transaction.serial_num,
                        family_ledger_serial_num,
                        payer_for_log,
                        member_serial_num,
                        final_split_amount
                    );
                }
                Err(e) => {
                    tracing::error!(
                        "创建分摊记录失败: transaction={}, member={}, error={}",
                        transaction.serial_num,
                        member_serial_num,
                        e
                    );
                    // 不阻塞交易创建，记录错误即可
                }
            }
        }
    }
    
    Ok(())
}
