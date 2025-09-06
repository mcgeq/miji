use std::str::FromStr;

use common::{
    BusinessCode,
    crud::hooks::Hooks,
    error::{AppError, MijiResult},
};
use sea_orm::{
    ActiveModelTrait, DatabaseTransaction, EntityTrait, IntoActiveModel, PrimaryKeyTrait,
    QuerySelect,
    prelude::{Decimal, async_trait::async_trait},
};
use snafu::GenerateImplicitData;

use crate::{
    dto::transactions::{
        CreateTransactionRequest, TransactionStatus, TransactionType, UpdateTransactionRequest,
    },
    error::MoneyError,
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
            update_account_balance(
                tx,
                &model.account_serial_num,
                transaction_type,
                model.amount,
                false,
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
        // Implement pre-delete validation or operations
        let transaction_status = TransactionStatus::from_str(&model.transaction_status)?;
        if transaction_status == TransactionStatus::Completed {
            return Err(AppError::simple(
                BusinessCode::MoneyTransactionDeclined,
                "无法删除已完成的交易",
            ));
        }
        if model.category == "Transfer" {
            if let Some(related_id) = &model.related_transaction_serial_num {
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
        }
        Ok(())
    }

    async fn after_delete(
        &self,
        tx: &DatabaseTransaction,
        id: &<entity::transactions::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()> {
        let transaction = entity::transactions::Entity::find_by_id(id.clone())
            .one(tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "交易不存在"))?;

        if transaction.category != "Transfer" && transaction.is_deleted {
            let transaction_type = TransactionType::from_str(&transaction.transaction_type)?;
            update_account_balance(
                tx,
                &transaction.account_serial_num,
                transaction_type,
                transaction.amount,
                true,
            )
            .await?;
        }

        if transaction.category == "Transfer" {
            if let Some(related_id) = &transaction.related_transaction_serial_num {
                let mut related_active = entity::transactions::Entity::find_by_id(related_id)
                    .one(tx)
                    .await?
                    .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "关联交易不存在"))?
                    .into_active_model();
                related_active.is_deleted = sea_orm::ActiveValue::Set(true);
                related_active.update(tx).await?;
            }
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

async fn update_account_balance(
    tx: &DatabaseTransaction,
    account_serial_num: &str,
    transaction_type: TransactionType,
    amount: Decimal,
    is_rollback: bool,
) -> MijiResult<()> {
    let account = entity::account::Entity::find_by_id(account_serial_num)
        .lock_exclusive()
        .one(tx)
        .await?
        .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "账户不存在"))?;

    let new_balance = match transaction_type {
        TransactionType::Income => {
            if is_rollback {
                account.balance - amount
            } else {
                account.balance + amount
            }
        }
        TransactionType::Expense => {
            if is_rollback {
                account.balance + amount
            } else {
                account.balance - amount
            }
        }
        TransactionType::Transfer => {
            return Err(AppError::simple(
                BusinessCode::MoneyTransferLimitExceeded,
                "转账交易不应在此更新余额",
            ));
        }
    };

    let mut account_active = account.into_active_model();
    account_active.balance = sea_orm::ActiveValue::Set(new_balance);
    account_active.update(tx).await?;
    Ok(())
}
