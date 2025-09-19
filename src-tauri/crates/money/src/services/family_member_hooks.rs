use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::family_member::{FamilyMemberCreate, FamilyMemberUpdate};

pub struct FamilyMemberHooks;

#[async_trait]
impl Hooks<entity::family_member::Entity, FamilyMemberCreate, FamilyMemberUpdate>
    for FamilyMemberHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &FamilyMemberCreate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_member::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_member::Model,
        _data: &FamilyMemberUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_member::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_member::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_member::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
