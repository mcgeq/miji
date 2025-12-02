use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

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
        _tx: &DatabaseTransaction,
        _model: &entity::project::Model,
    ) -> MijiResult<()> {
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
