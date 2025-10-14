use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, _manager: &SchemaManager) -> Result<(), DbErr> {
        // 这个迁移现在只用于标记，实际的默认用户创建在应用启动时进行
        // 这样可以确保密码被正确哈希
        Ok(())
    }

    async fn down(&self, _manager: &SchemaManager) -> Result<(), DbErr> {
        // 这个迁移现在只用于标记，不需要回滚操作
        Ok(())
    }
}
