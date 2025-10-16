use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

use crate::dto::installment::{InstallmentPlanCreate, InstallmentPlanUpdate};

pub struct InstallmentHooks;

#[async_trait]
impl Hooks<entity::installment_plans::Entity, InstallmentPlanCreate, InstallmentPlanUpdate>
    for InstallmentHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &InstallmentPlanCreate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::installment_plans::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::installment_plans::Model,
        _data: &InstallmentPlanUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::installment_plans::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::installment_plans::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::installment_plans::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
