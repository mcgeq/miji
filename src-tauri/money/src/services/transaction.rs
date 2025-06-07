use common::entity::account;
use common::entity::sea_orm_active_enums::TransactionType;
use common::error::MijiError;
use common::sql_error::{SQLError, not_found_error};
use common::{entity::transaction, error::MijiResult, utils::uuid::McgUuid};

use crate::dto::{PaginationParams, TransactionDto};
use crate::error::MoneyError;

use sea_orm::{
    ActiveModelTrait, ColumnTrait, DatabaseConnection, DatabaseTransaction, EntityTrait,
    PaginatorTrait, QueryFilter, QueryOrder, Set, TransactionTrait,
};

pub struct TransactionService;

impl TransactionService {
    pub async fn list(
        account_serial_num: &str,
        pagination_params: &PaginationParams,
        db: &DatabaseConnection,
    ) -> MijiResult<Vec<transaction::Model>> {
        let paginator = transaction::Entity::find()
            .filter(transaction::Column::AccountSerialNum.eq(account_serial_num))
            .order_by_desc(transaction::Column::CreatedAt)
            .paginate(db, pagination_params.page_size());
        let result = paginator
            .fetch_page(pagination_params.page() - 1)
            .await
            .map_err(SQLError::from)?;
        Ok(result)
    }

    pub async fn get(
        serial_num: &str,
        account_serial_num: &str,
        db: &DatabaseConnection,
    ) -> MijiResult<transaction::Model> {
        Self::ensure_transaction_belongs_to_account(serial_num, account_serial_num, db).await
    }

    pub async fn create(
        transaction_dto: TransactionDto,
        db: &DatabaseConnection,
    ) -> MijiResult<transaction::Model> {
        let txn = db
            .begin()
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?;
        let transaction = transaction::ActiveModel {
            serial_num: Set(McgUuid::uuid(32)),
            transaction_type: Set(transaction_dto.core.transaction_type),
            transaction_status: Set(transaction_dto.core.transaction_status),
            date: Set(transaction_dto.core.date),
            amount: Set(transaction_dto.core.amount),
            currency: Set(transaction_dto.core.currency),
            description: Set(transaction_dto.core.description),
            notes: Set(transaction_dto.core.notes),
            account_serial_num: Set(transaction_dto.core.account_serial_num.clone()),
            category: Set(transaction_dto.core.category),
            sub_category: Set(transaction_dto.core.sub_category),
            tags: Set(transaction_dto.core.tags),
            split_members: Set(transaction_dto.core.split_members),
            payment_method: Set(transaction_dto.core.payment_method),
            actual_payer_account: Set(transaction_dto.core.actual_payer_account),
            ..Default::default()
        };
        let inserted = transaction.insert(&txn).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        let delta = match inserted.transaction_type {
            TransactionType::Income => inserted.amount,
            TransactionType::Expense => -inserted.amount,
        };

        Self::adjust_account_balance(&inserted.account_serial_num, delta, &txn).await?;

        txn.commit()
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?;
        Ok(inserted)
    }

    pub async fn update(
        serial_num: &str,
        account_serial_num: &str,
        transaction_dto: TransactionDto,
        db: &DatabaseConnection,
    ) -> MijiResult<transaction::Model> {
        let txn = db
            .begin()
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?;
        let existing =
            Self::ensure_transaction_belongs_to_account(serial_num, account_serial_num, &txn)
                .await?;
        let mut active_model: transaction::ActiveModel = existing.clone().into();
        active_model.transaction_type = Set(transaction_dto.core.transaction_type.clone());
        active_model.transaction_status = Set(transaction_dto.core.transaction_status);
        active_model.date = Set(transaction_dto.core.date);
        active_model.amount = Set(transaction_dto.core.amount);
        active_model.currency = Set(transaction_dto.core.currency);
        active_model.description = Set(transaction_dto.core.description);
        active_model.notes = Set(transaction_dto.core.notes);
        active_model.account_serial_num = Set(transaction_dto.core.account_serial_num.clone());
        active_model.category = Set(transaction_dto.core.category);
        active_model.sub_category = Set(transaction_dto.core.sub_category);
        active_model.tags = Set(transaction_dto.core.tags);
        active_model.split_members = Set(transaction_dto.core.split_members);
        active_model.payment_method = Set(transaction_dto.core.payment_method);
        active_model.actual_payer_account = Set(transaction_dto.core.actual_payer_account);

        let updated = active_model.update(&txn).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        let old_delta = match existing.transaction_type {
            TransactionType::Income => -existing.amount,
            TransactionType::Expense => existing.amount,
        };

        let new_delta = match transaction_dto.core.transaction_type {
            TransactionType::Income => transaction_dto.core.amount,
            TransactionType::Expense => -transaction_dto.core.amount,
        };
        if existing.account_serial_num == transaction_dto.core.account_serial_num {
            // 同账户
            let diff = old_delta + new_delta;
            Self::adjust_account_balance(&transaction_dto.core.account_serial_num, diff, &txn)
                .await?;
        } else {
            // 账户迁移
            Self::adjust_account_balance(&existing.account_serial_num, old_delta, &txn).await?;
            Self::adjust_account_balance(&transaction_dto.core.account_serial_num, new_delta, &txn)
                .await?;
        }
        txn.commit()
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?;
        Ok(updated)
    }

    pub async fn delete(
        serial_num: &str,
        account_serial_num: &str,
        db: &DatabaseConnection,
    ) -> MijiResult<transaction::Model> {
        let txn = db
            .begin()
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?;

        let existing =
            Self::ensure_transaction_belongs_to_account(serial_num, account_serial_num, &txn)
                .await?;

        let delta = match existing.transaction_type {
            TransactionType::Income => -existing.amount,
            TransactionType::Expense => existing.amount,
        };

        Self::adjust_account_balance(&existing.account_serial_num, delta, &txn).await?;

        transaction::Entity::delete_by_id(serial_num)
            .exec(&txn)
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?;

        txn.commit()
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?;
        Ok(existing)
    }

    async fn adjust_account_balance(
        account_serial_num: &str,
        delta: sea_orm::prelude::Decimal,
        db: &DatabaseTransaction,
    ) -> MijiResult<()> {
        let account = account::Entity::find_by_id(account_serial_num)
            .one(db)
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?
            .ok_or_else(|| not_found_error(account_serial_num))?;

        let old_balance = account.balance;
        let mut active: account::ActiveModel = account.into();
        active.balance = Set(old_balance + delta);
        active
            .update(db)
            .await
            .map_err(|e| MijiError::from(SQLError::from(e)))?;
        Ok(())
    }

    async fn ensure_transaction_belongs_to_account(
        serial_num: &str,
        account_serial_num: &str,
        db: &impl sea_orm::ConnectionTrait,
    ) -> MijiResult<transaction::Model> {
        let txn = transaction::Entity::find_by_id(serial_num)
            .one(db)
            .await
            .map_err(SQLError::from)?
            .ok_or_else(|| not_found_error(serial_num))?;

        if txn.account_serial_num != account_serial_num {
            return Err(MoneyError::PermissionDenied {
                code: common::business_code::BusinessCode::PermissionDenied,
                message: "Transaction does not belong to the account".to_string(),
            }
            .into());
        }

        Ok(txn)
    }
}
