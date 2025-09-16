use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::period_settings::{PeriodSettingsCreate, PeriodSettingsUpdate};

#[derive(Debug)]
pub struct PeriodSettingsHooks;

#[async_trait]
impl Hooks<entity::period_settings::Entity, PeriodSettingsCreate, PeriodSettingsUpdate>
    for PeriodSettingsHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &PeriodSettingsCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_settings::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_settings::Model,
        _data: &PeriodSettingsUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_settings::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_settings::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::period_settings::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
