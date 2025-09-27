use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::todo::{TodoCreate, TodoUpdate};

#[derive(Debug)]
pub struct TodoHooks;

#[async_trait]
impl Hooks<entity::todo::Entity, TodoCreate, TodoUpdate> for TodoHooks {
    async fn before_create(&self, _tx: &DatabaseTransaction, _data: &TodoCreate) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo::Model,
        _data: &TodoUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
