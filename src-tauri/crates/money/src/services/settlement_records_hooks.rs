use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

#[derive(Debug)]
pub struct SettlementRecordsHooks;

#[async_trait]
impl
    Hooks<
        entity::settlement_records::Entity,
        crate::dto::settlement_records::SettlementRecordCreate,
        crate::dto::settlement_records::SettlementRecordUpdate,
    > for SettlementRecordsHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &crate::dto::settlement_records::SettlementRecordCreate,
    ) -> MijiResult<()> {
        // 可以在这里添加创建前的验证逻辑
        // 例如：验证结算周期的合理性
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::settlement_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加创建后的处理逻辑
        // 例如：发送结算通知
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::settlement_records::Model,
        _data: &crate::dto::settlement_records::SettlementRecordUpdate,
    ) -> MijiResult<()> {
        // 可以在这里添加更新前的验证逻辑
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::settlement_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加更新后的处理逻辑
        // 例如：当结算完成时，发送完成通知
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::settlement_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除前的验证逻辑
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::settlement_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除后的清理逻辑
        Ok(())
    }
}
