use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::period_daily_records::{PeriodDailyRecordCreate, PeriodDailyRecordUpdate};

#[derive(Debug)]
pub struct PeriodDailyRecordHooks;

#[async_trait]
impl Hooks<entity::period_daily_records::Entity, PeriodDailyRecordCreate, PeriodDailyRecordUpdate>
    for PeriodDailyRecordHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &PeriodDailyRecordCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_daily_records::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_daily_records::Model,
        _data: &PeriodDailyRecordUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_daily_records::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_daily_records::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(&self, _tx: &DatabaseTransaction, _id: &String) -> MijiResult<()> {
        Ok(())
    }
}
