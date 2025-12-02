use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::sub_categories::{SubCategoryCreate, SubCategoryUpdate};

pub struct SubCategoryHooks;

#[async_trait]
impl Hooks<entity::sub_categories::Entity, SubCategoryCreate, SubCategoryUpdate>
    for SubCategoryHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &SubCategoryCreate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::sub_categories::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::sub_categories::Model,
        _data: &SubCategoryUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::sub_categories::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::sub_categories::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::sub_categories::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
