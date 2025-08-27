use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::account::{CreateAccountRequest, UpdateAccountRequest};
/// 空操作钩子
pub struct AccountHooks;
/// 账户操作钩子
#[async_trait]
impl Hooks<entity::account::Entity, CreateAccountRequest, UpdateAccountRequest> for AccountHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &CreateAccountRequest,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::account::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::account::Model,
        _data: &UpdateAccountRequest,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::account::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::account::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _id: &<entity::account::PrimaryKey as sea_orm::PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()> {
        Ok(())
    }
}


