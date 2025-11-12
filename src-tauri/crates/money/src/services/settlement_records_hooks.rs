use common::{crud::service::CrudHooks, error::MijiResult};
use sea_orm::{prelude::async_trait::async_trait, DbConn};

#[derive(Debug)]
pub struct SettlementRecordsHooks;

#[async_trait]
impl CrudHooks<entity::settlement_records::Entity> for SettlementRecordsHooks {
    async fn before_create(
        &self,
        _db: &DbConn,
        _model: &mut entity::settlement_records::ActiveModel,
    ) -> MijiResult<()> {
        // 可以在这里添加创建前的验证逻辑
        // 例如：验证结算周期的合理性
        Ok(())
    }

    async fn after_create(
        &self,
        _db: &DbConn,
        _model: &entity::settlement_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加创建后的处理逻辑
        // 例如：发送结算通知
        Ok(())
    }

    async fn before_update(
        &self,
        _db: &DbConn,
        _model: &mut entity::settlement_records::ActiveModel,
    ) -> MijiResult<()> {
        // 可以在这里添加更新前的验证逻辑
        Ok(())
    }

    async fn after_update(
        &self,
        _db: &DbConn,
        _model: &entity::settlement_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加更新后的处理逻辑
        // 例如：当结算完成时，发送完成通知
        Ok(())
    }

    async fn before_delete(
        &self,
        _db: &DbConn,
        _model: &entity::settlement_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除前的验证逻辑
        Ok(())
    }

    async fn after_delete(
        &self,
        _db: &DbConn,
        _model: &entity::settlement_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除后的清理逻辑
        Ok(())
    }
}
