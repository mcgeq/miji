use common::{crud::service::CrudHooks, error::MijiResult};
use sea_orm::{prelude::async_trait::async_trait, DbConn};

#[derive(Debug)]
pub struct SplitRulesHooks;

#[async_trait]
impl CrudHooks<entity::split_rules::Entity> for SplitRulesHooks {
    async fn before_create(
        &self,
        _db: &DbConn,
        _model: &mut entity::split_rules::ActiveModel,
    ) -> MijiResult<()> {
        // 可以在这里添加创建前的验证逻辑
        Ok(())
    }

    async fn after_create(
        &self,
        _db: &DbConn,
        _model: &entity::split_rules::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加创建后的处理逻辑，如日志记录
        Ok(())
    }

    async fn before_update(
        &self,
        _db: &DbConn,
        _model: &mut entity::split_rules::ActiveModel,
    ) -> MijiResult<()> {
        // 可以在这里添加更新前的验证逻辑
        Ok(())
    }

    async fn after_update(
        &self,
        _db: &DbConn,
        _model: &entity::split_rules::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加更新后的处理逻辑
        Ok(())
    }

    async fn before_delete(
        &self,
        _db: &DbConn,
        _model: &entity::split_rules::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除前的验证逻辑
        // 例如：检查是否有关联的分摊记录
        Ok(())
    }

    async fn after_delete(
        &self,
        _db: &DbConn,
        _model: &entity::split_rules::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除后的清理逻辑
        Ok(())
    }
}
