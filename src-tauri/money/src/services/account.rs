use common::entity::account;
use common::error::MijiError;
use common::sql_error::{SQLError, not_found_error};
use common::utils::date::DateUtils;
use common::{error::MijiResult, utils::uuid::McgUuid};

use crate::dto::AccountDto;

use sea_orm::prelude::Decimal;
use sea_orm::{ActiveModelTrait, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, Set};

pub struct AccountService;

impl AccountService {
    pub async fn get(serial_num: &str, db: &DatabaseConnection) -> MijiResult<account::Model> {
        let account = account::Entity::find()
            .filter(account::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;
        Ok(account)
    }

    pub async fn create(
        account_dto: AccountDto,
        db: &DatabaseConnection,
    ) -> MijiResult<account::Model> {
        let account = account::ActiveModel {
            serial_num: Set(McgUuid::uuid(32)),
            name: Set(account_dto.core.name),
            description: Set(account_dto.core.description),
            is_shared: Set(account_dto.core.is_shared),
            balance: Set(Decimal::new(0, 2)),
            currency: Set("USD".to_string()),
            owner_id: Set("default_owner".to_string()),
            created_at: Set(DateUtils::current_datetime_local_fixed()),
            ..Default::default()
        };
        let inserted = account.insert(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        Ok(inserted)
    }

    pub async fn update(
        serial_num: &str,
        account_dto: AccountDto,
        db: &DatabaseConnection,
    ) -> MijiResult<account::Model> {
        let account = account::Entity::find()
            .filter(account::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;
        let mut active_model: account::ActiveModel = account.into();
        active_model.name = Set(account_dto.core.name);
        active_model.description = Set(account_dto.core.description);
        active_model.is_shared = Set(account_dto.core.is_shared);
        active_model.updated_at = Set(Some(DateUtils::current_datetime_local_fixed()));
        let updated = active_model.update(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(updated)
    }
    pub async fn delete(serial_num: &str, db: &DatabaseConnection) -> MijiResult<account::Model> {
        let mut res_dto = account::Entity::find()
            .filter(account::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;
        res_dto.is_active = false;
        let active_model: account::ActiveModel = res_dto.clone().into();
        active_model.update(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(res_dto)
    }
}
