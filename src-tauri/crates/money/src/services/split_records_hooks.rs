use common::{crud::hooks::Hooks, error::MijiResult};
use sea_orm::{prelude::async_trait::async_trait, DatabaseTransaction};

#[derive(Debug)]
pub struct SplitRecordsHooks;

#[async_trait]
impl Hooks<entity::split_records::Entity, crate::dto::split_records::SplitRecordCreate, crate::dto::split_records::SplitRecordUpdate> for SplitRecordsHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &crate::dto::split_records::SplitRecordCreate,
    ) -> MijiResult<()> {
        // 可以在这里添加创建前的验证逻辑
        // 例如：验证付款人和欠款人不能是同一人
        Ok(())
    }

    async fn after_create(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加创建后的处理逻辑
        // 例如：更新成员的债务统计
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_records::Model,
        _data: &crate::dto::split_records::SplitRecordUpdate,
    ) -> MijiResult<()> {
        // 可以在这里添加更新前的验证逻辑
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加更新后的处理逻辑
        // 例如：当状态变为已支付时，更新债务关系
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除前的验证逻辑
        Ok(())
    }

    async fn after_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::split_records::Model,
    ) -> MijiResult<()> {
        // 可以在这里添加删除后的清理逻辑
        Ok(())
    }
}
