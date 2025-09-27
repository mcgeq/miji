use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

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
        _tx: &DatabaseTransaction,
        _model: &entity::tag::Model,
    ) -> MijiResult<()> {
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
