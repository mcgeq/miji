use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::bil_reminder::{BilReminderCreate, BilReminderUpdate};

// 空操作钩子
pub struct BilReminderHooks;

#[async_trait]
impl Hooks<entity::bil_reminder::Entity, BilReminderCreate, BilReminderUpdate>
    for BilReminderHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &BilReminderCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::bil_reminder::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::bil_reminder::Model,
        _data: &BilReminderUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::bil_reminder::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::bil_reminder::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(&self, _tx: &DatabaseTransaction, _id: &String) -> MijiResult<()> {
        Ok(())
    }
}
