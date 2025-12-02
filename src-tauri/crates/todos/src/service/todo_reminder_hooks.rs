use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::todo_reminder::{ReminderCreate, ReminderUpdate};

#[derive(Debug)]
pub struct TodoReminderHooks;

#[async_trait]
impl Hooks<entity::reminder::Entity, ReminderCreate, ReminderUpdate> for TodoReminderHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &ReminderCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::reminder::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::reminder::Model,
        _data: &ReminderUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::reminder::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::reminder::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::reminder::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
