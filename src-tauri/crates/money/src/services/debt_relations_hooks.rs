use common::{crud::service::CrudHooks, error::MijiResult};
use sea_orm::{prelude::async_trait::async_trait, DbConn};

#[derive(Debug)]
pub struct DebtRelationsHooks;

#[async_trait]
impl CrudHooks<entity::debt_relations::Entity> for DebtRelationsHooks {
    async fn before_create(
        &self,
        _db: &DbConn,
        _model: &mut entity::debt_relations::ActiveModel,
    ) -> MijiResult<()> {
        // 可以在这里添加创建前的验证逻辑
        // 例如：验证债权人和债务人不能是同一人
        Ok(())
    }

    async fn after_create(
        &self,
        _db: &DbConn,
        _model: &entity::debt_relations::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加创建后的处理逻辑
        // 例如：更新成员的债务统计
        Ok(())
    }

    async fn before_update(
        &self,
        _db: &DbConn,
        _model: &mut entity::debt_relations::ActiveModel,
    ) -> MijiResult<()> {
        // 可以在这里添加更新前的验证逻辑
        Ok(())
    }

    async fn after_update(
        &self,
        _db: &DbConn,
        _model: &entity::debt_relations::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加更新后的处理逻辑
        // 例如：当债务状态变为已结算时，发送通知
        Ok(())
    }

    async fn before_delete(
        &self,
        _db: &DbConn,
        _model: &entity::debt_relations::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除前的验证逻辑
        Ok(())
    }

    async fn after_delete(
        &self,
        _db: &DbConn,
        _model: &entity::debt_relations::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除后的清理逻辑
        Ok(())
    }
}
