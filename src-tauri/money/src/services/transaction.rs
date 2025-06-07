use common::error::MijiError;
use common::sql_error::{SQLError, not_found_error};
use common::{entity::transaction, error::MijiResult, utils::uuid::McgUuid};

use crate::dto::TransactionDto;

use sea_orm::{ActiveModelTrait, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, Set};

pub struct TransactionService;

impl TransactionService {
    pub async fn get(serial_num: &str, db: &DatabaseConnection) -> MijiResult<transaction::Model> {
        let transaction = transaction::Entity::find()
            .filter(transaction::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;

        Ok(transaction)
    }

    pub async fn create(
        transaction_dto: TransactionDto,
        db: &DatabaseConnection,
    ) -> MijiResult<transaction::Model> {
        let transaction = transaction::ActiveModel {
            serial_num: Set(McgUuid::uuid(32)),
            transaction_type: Set(transaction_dto.core.transaction_type),
            transaction_status: Set(transaction_dto.core.transaction_status),
            date: Set(transaction_dto.core.date),
            amount: Set(transaction_dto.core.amount),
            currency: Set(transaction_dto.core.currency),
            description: Set(transaction_dto.core.description),
            notes: Set(transaction_dto.core.notes),
            account_serial_num: Set(transaction_dto.core.account_serial_num),
            category: Set(transaction_dto.core.category),
            sub_category: Set(transaction_dto.core.sub_category),
            tags: Set(transaction_dto.core.tags),
            split_members: Set(transaction_dto.core.split_members),
            payment_method: Set(transaction_dto.core.payment_method),
            actual_payer_account: Set(transaction_dto.core.actual_payer_account),
            ..Default::default()
        };
        let inserted = transaction.insert(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(inserted)
    }

    pub async fn update(
        serial_num: &str,
        transaction_dto: TransactionDto,
        db: &DatabaseConnection,
    ) -> MijiResult<transaction::Model> {
        let transaction = transaction::Entity::find()
            .filter(transaction::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;
        let mut active_model: transaction::ActiveModel = transaction.into();
        active_model.transaction_type = Set(transaction_dto.core.transaction_type);
        active_model.transaction_status = Set(transaction_dto.core.transaction_status);
        active_model.date = Set(transaction_dto.core.date);
        active_model.amount = Set(transaction_dto.core.amount);
        active_model.currency = Set(transaction_dto.core.currency);
        active_model.description = Set(transaction_dto.core.description);
        active_model.notes = Set(transaction_dto.core.notes);
        active_model.account_serial_num = Set(transaction_dto.core.account_serial_num);
        active_model.category = Set(transaction_dto.core.category);
        active_model.sub_category = Set(transaction_dto.core.sub_category);
        active_model.tags = Set(transaction_dto.core.tags);
        active_model.split_members = Set(transaction_dto.core.split_members);
        active_model.payment_method = Set(transaction_dto.core.payment_method);
        active_model.actual_payer_account = Set(transaction_dto.core.actual_payer_account);
        let updated = active_model.update(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(updated)
    }

    pub async fn delete(
        serial_num: &str,
        db: &DatabaseConnection,
    ) -> MijiResult<transaction::Model> {
        let res_dto = transaction::Entity::find()
            .filter(transaction::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;
        transaction::Entity::delete_by_id(serial_num)
            .exec(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;
        Ok(res_dto)
    }
}
