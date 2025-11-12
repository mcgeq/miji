use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{DatabaseTransaction, prelude::async_trait::async_trait};

#[derive(Debug)]
pub struct SplitRulesHooks;

#[async_trait]
impl
    Hooks<
        entity::split_rules::Entity,
        crate::dto::split_rules::SplitRuleCreate,
        crate::dto::split_rules::SplitRuleUpdate,
    > for SplitRulesHooks
{
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &crate::dto::split_rules::SplitRuleCreate,
    ) -> MijiResult<()> {
        // 可以在这里添加创建前的验证逻辑
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_rules::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加创建后的逻辑
        // 例如：记录操作日志
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_rules::Model,
        _data: &crate::dto::split_rules::SplitRuleUpdate,
    ) -> MijiResult<()> {
        // 可以在这里添加更新前的验证逻辑
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_rules::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加更新后的逻辑
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_rules::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除前的验证逻辑
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_rules::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除后的逻辑
        Ok(())
    }
}
