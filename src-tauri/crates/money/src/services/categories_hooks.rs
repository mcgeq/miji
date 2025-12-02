use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::categories::{CategoryCreate, CategoryUpdate};

pub struct CategoryHooks;

#[async_trait]
impl Hooks<entity::categories::Entity, CategoryCreate, CategoryUpdate> for CategoryHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &CategoryCreate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::categories::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::categories::Model,
        _data: &CategoryUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::categories::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::categories::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::categories::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
