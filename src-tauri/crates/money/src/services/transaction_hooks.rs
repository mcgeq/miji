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
    dto::transactions::{
        CreateTransactionRequest, TransactionStatus, TransactionType, UpdateTransactionRequest,
    },
    error::MoneyError,
};
use tracing::info;

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
            info!("is_installment {}", model.is_installment.unwrap());
            info!(
                "installment_plan_serial_num {:?}",
                &model.installment_plan_serial_num
            );
            info!("total period {:?}", model.total_periods);
            info!("remaining_periods {:?}", model.remaining_periods);
            info!("installment amount {:?}", model.amount);
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
