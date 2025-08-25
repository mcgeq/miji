use common::{
    BusinessCode,
    crud::hooks::Hooks,
    error::{AppError, MijiResult},
};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::users::{CreateUserDto, UpdateUserDto};

pub struct UserHooks;

#[async_trait]
impl Hooks<entity::users::Entity, CreateUserDto, UpdateUserDto> for UserHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        data: &CreateUserDto,
    ) -> MijiResult<()> {
        if data.serial_num.len() != 38 {
            return Err(AppError::validation_failed(
                BusinessCode::ValidationError,
                "Serial number must be exactly 38 characters",
                None,
            ));
        }
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::users::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::users::Model,
        _data: &UpdateUserDto,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::users::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::users::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_delete(&self, _tx: &DatabaseTransaction, _id: &String) -> MijiResult<()> {
        Ok(())
    }
}
