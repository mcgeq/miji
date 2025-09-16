use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::budget::{BudgetCreate, BudgetUpdate};

#[derive(Debug)]
pub struct BudgetHooks;

#[async_trait]
impl Hooks<entity::budget::Entity, BudgetCreate, BudgetUpdate> for BudgetHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &BudgetCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
        _data: &BudgetUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
