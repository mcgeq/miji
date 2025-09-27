use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::todo_tag::{TodoTagCreate, TodoTagUpdate};

#[derive(Debug)]
pub struct TodoTagHooks;

#[async_trait]
impl Hooks<entity::todo_tag::Entity, TodoTagCreate, TodoTagUpdate> for TodoTagHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &TodoTagCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_tag::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_tag::Model,
        _data: &TodoTagUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_tag::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_tag::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_tag::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
