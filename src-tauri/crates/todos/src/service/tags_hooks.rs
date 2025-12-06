use common::{
    BusinessCode,
    crud::hooks::Hooks,
    error::{AppError, MijiResult},
};
use sea_orm::{
    ColumnTrait, DatabaseTransaction, EntityTrait, PaginatorTrait, QueryFilter,
    prelude::async_trait::async_trait,
};

use crate::dto::tags::{TagCreate, TagUpdate};

#[derive(Debug)]
pub struct TagsHooks;

#[async_trait]
impl Hooks<entity::tag::Entity, TagCreate, TagUpdate> for TagsHooks {
    async fn before_create(&self, _tx: &DatabaseTransaction, _data: &TagCreate) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::tag::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::tag::Model,
        _data: &TagUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::tag::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::tag::Model,
    ) -> MijiResult<()> {
        // 检查是否有待办事项关联到该标签
        let todo_count = entity::todo_tag::Entity::find()
            .filter(entity::todo_tag::Column::TagSerialNum.eq(&model.serial_num))
            .count(tx)
            .await?;

        if todo_count > 0 {
            return Err(AppError::simple(
                BusinessCode::ReferenceExists,
                format!(
                    "无法删除标签 '{}'，因为有 {} 个待办事项正在使用该标签",
                    model.name, todo_count
                ),
            ));
        }

        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::tag::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
