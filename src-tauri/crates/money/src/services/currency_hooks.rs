use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::currency::{CreateCurrencyRequest, UpdateCurrencyRequest};

// 空操作钩子
pub struct NoOpHooks;

#[async_trait]
impl Hooks<entity::currency::Entity, CreateCurrencyRequest, UpdateCurrencyRequest> for NoOpHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &CreateCurrencyRequest,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::currency::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::currency::Model,
        _data: &UpdateCurrencyRequest,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::currency::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::currency::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(&self, _tx: &DatabaseTransaction, _id: &String) -> MijiResult<()> {
        Ok(())
    }
}
