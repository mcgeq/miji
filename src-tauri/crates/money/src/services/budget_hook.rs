use common::{
    crud::{hooks::Hooks, service::update_entity_columns_simple},
    error::MijiResult,
    utils::date::DateUtils,
};
use sea_orm::{
    DatabaseTransaction,
    prelude::{Decimal, Expr, async_trait::async_trait},
};

use crate::dto::budget::{BudgetCreate, BudgetUpdate};
use tracing::info;

#[derive(Debug)]
pub struct BudgetHooks;

#[async_trait]
impl Hooks<entity::budget::Entity, BudgetCreate, BudgetUpdate> for BudgetHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &BudgetCreate,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
        _data: &BudgetUpdate,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_update(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::budget::Model,
    ) -> MijiResult<()> {
        info!("budget after model {:?}", model);
        let new_progress = if model.used_amount.is_zero() {
            Decimal::ZERO
        } else {
            ((model.used_amount / model.amount) * Decimal::from(100)).round_dp(2)
        };

        update_entity_columns_simple::<entity::budget::Entity, _>(
            tx,
            vec![(
                entity::budget::Column::SerialNum,
                vec![model.serial_num.clone()],
            )],
            vec![
                (entity::budget::Column::Progress, Expr::value(new_progress)),
                (
                    entity::budget::Column::UpdatedAt,
                    Expr::value(DateUtils::local_now()),
                ),
            ],
        )
        .await
        .map(|_| ())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::budget::Model,
    ) -> MijiResult<()> {
        Ok(())
    }
}
