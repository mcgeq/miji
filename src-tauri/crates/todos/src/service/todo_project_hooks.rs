use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::todo_project::{TodoProjectCreate, TodoProjectUpdate};

#[derive(Debug)]
pub struct TodoProjectHooks;

#[async_trait]
impl Hooks<entity::todo_project::Entity, TodoProjectCreate, TodoProjectUpdate>
    for TodoProjectHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &TodoProjectCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_project::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_project::Model,
        _data: &TodoProjectUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_project::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_project::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::todo_project::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
