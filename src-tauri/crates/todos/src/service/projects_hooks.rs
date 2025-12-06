use common::{
    BusinessCode,
    crud::hooks::Hooks,
    error::{AppError, MijiResult},
};
use sea_orm::{
    ColumnTrait, DatabaseTransaction, EntityTrait, PaginatorTrait, QueryFilter,
    prelude::async_trait::async_trait,
};

use crate::dto::projects::{ProjectCreate, ProjectUpdate};

#[derive(Debug)]
pub struct ProjectHooks;

#[async_trait]
impl Hooks<entity::project::Entity, ProjectCreate, ProjectUpdate> for ProjectHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &ProjectCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::project::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::project::Model,
        _data: &ProjectUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::project::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::project::Model,
    ) -> MijiResult<()> {
        // 检查是否有待办事项关联到该项目
        let todo_count = entity::todo_project::Entity::find()
            .filter(entity::todo_project::Column::ProjectSerialNum.eq(&model.serial_num))
            .count(tx)
            .await?;

        if todo_count > 0 {
            return Err(AppError::simple(
                BusinessCode::ReferenceExists,
                format!(
                    "无法删除项目 '{}'，因为有 {} 个待办事项正在使用该项目",
                    model.name, todo_count
                ),
            ));
        }

        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::project::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
