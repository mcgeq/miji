use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{prelude::async_trait::async_trait, DatabaseTransaction};

use crate::dto::period_records::{PeriodRecordsCreate, PeriodRecordsUpdate};

#[derive(Debug)]
pub struct PeriodRecordsHooks;

#[async_trait]
impl Hooks<entity::period_records::Entity, PeriodRecordsCreate, PeriodRecordsUpdate> for PeriodRecordsHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &PeriodRecordsCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_records::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_records::Model,
        _data: &PeriodRecordsUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_records::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_records::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(&self, _tx: &DatabaseTransaction, _id: &String) -> MijiResult<()> {
        Ok(())
    }

}

