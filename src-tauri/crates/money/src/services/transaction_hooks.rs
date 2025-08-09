use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, PrimaryKeyTrait, prelude::async_trait::async_trait};

use crate::dto::transactions::{CreateTransactionRequest, UpdateTransactionRequest};

#[derive(Debug)]
pub struct NoOpHooks;

#[async_trait]
impl Hooks<entity::transactions::Entity, CreateTransactionRequest, UpdateTransactionRequest>
    for NoOpHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &CreateTransactionRequest,
    ) -> MijiResult<()> {
        // Implement pre-create validation or operations
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::transactions::Model,
    ) -> MijiResult<()> {
        // Implement post-create operations
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::transactions::Model,
        _data: &UpdateTransactionRequest,
    ) -> MijiResult<()> {
        // Implement pre-update validation or operations
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::transactions::Model,
    ) -> MijiResult<()> {
        // Implement post-update operations
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::transactions::Model,
    ) -> MijiResult<()> {
        // Implement pre-delete validation or operations
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _id: &<entity::transactions::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()> {
        // Implement post-delete operations
        Ok(())
    }
}
