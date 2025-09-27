use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::todo_task_dependency::{TaskDependencyCreate, TaskDependencyUpdate};

#[derive(Debug)]
pub struct TodoTaskDependencyHooks;

#[async_trait]
impl Hooks<entity::task_dependency::Entity, TaskDependencyCreate, TaskDependencyUpdate>
    for TodoTaskDependencyHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &TaskDependencyCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::task_dependency::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::task_dependency::Model,
        _data: &TaskDependencyUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::task_dependency::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::task_dependency::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::task_dependency::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
