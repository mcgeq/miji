use async_trait::async_trait;
use sea_orm::{DatabaseTransaction, EntityTrait, PrimaryKeyTrait};
use crate::error::MijiResult;

/// CRUD 操作钩子 trait
#[async_trait]
pub trait Hooks<E, C, U>
where
    E: EntityTrait,
{
    async fn before_create(
        &self,
        tx: &DatabaseTransaction,
        data: &C
    ) -> MijiResult<()>;

    async fn after_create(
        &self,
        tx: &DatabaseTransaction,
        model: &E::Model
    ) -> MijiResult<()>;

    async fn before_update(
        &self,
        tx: &DatabaseTransaction,
        model: &E::Model,
        data: &U
    ) -> MijiResult<()>;

    async fn after_update(
        &self,
        tx: &DatabaseTransaction,
        model: &E::Model
    ) -> MijiResult<()>;

    async fn before_delete(
        &self,
        tx: &DatabaseTransaction,
        model: &E::Model
    ) -> MijiResult<()>;

    async fn after_delete(
        &self,
        tx: &DatabaseTransaction,
        id: &<E::PrimaryKey as PrimaryKeyTrait>::ValueType
    ) -> MijiResult<()>;
}

/// 空操作钩子
pub struct NoOpHooks;

#[async_trait]
impl<E, C, U> Hooks<E, C, U> for NoOpHooks
where
    E: EntityTrait,
{
    async fn before_create(&self, _tx: &DatabaseTransaction, _data: &C) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(&self, _tx: &DatabaseTransaction, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(&self, _tx: &DatabaseTransaction, _model: &E::Model,
        _data: &U) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(&self, _tx: &DatabaseTransaction, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(&self, _tx: &DatabaseTransaction, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(&self, _tx: &DatabaseTransaction,
        _id: &<E::PrimaryKey as PrimaryKeyTrait>::ValueType) -> MijiResult<()> {
        Ok(())
    }
}
