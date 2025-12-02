use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

#[derive(Debug)]
pub struct FamilyLedgerHooks;

#[async_trait]
impl
    Hooks<
        entity::family_ledger::Entity,
        crate::dto::family_ledger::FamilyLedgerCreate,
        crate::dto::family_ledger::FamilyLedgerUpdate,
    > for FamilyLedgerHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &crate::dto::family_ledger::FamilyLedgerCreate,
    ) -> MijiResult<()> {
        // 可以在这里添加创建前的验证逻辑
        // 例如：验证债权人和债务人不能是同一人
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_ledger::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加创建后的处理逻辑
        // 例如：更新成员的债务统计
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_ledger::Model,
        _data: &crate::dto::family_ledger::FamilyLedgerUpdate,
    ) -> MijiResult<()> {
        // 可以在这里添加更新前的验证逻辑
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_ledger::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加更新后的处理逻辑
        // 例如：当债务状态变为已结算时，发送通知
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_ledger::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除前的验证逻辑
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::family_ledger::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除后的清理逻辑
        Ok(())
    }
}
