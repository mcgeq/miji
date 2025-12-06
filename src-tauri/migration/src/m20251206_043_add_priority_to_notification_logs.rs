use crate::schema::NotificationLogs;
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加 priority 字段到 notification_logs 表
        manager
            .alter_table(
                Table::alter()
                    .table(NotificationLogs::Table)
                    .add_column(
                        ColumnDef::new(NotificationLogs::Priority)
                            .string()
                            .not_null()
                            .default("Normal"), // 默认优先级为 Normal
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引以优化按优先级查询
        manager
            .create_index(
                Index::create()
                    .name("idx_notification_logs_priority")
                    .table(NotificationLogs::Table)
                    .col(NotificationLogs::Priority)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除索引
        manager
            .drop_index(
                Index::drop()
                    .name("idx_notification_logs_priority")
                    .table(NotificationLogs::Table)
                    .to_owned(),
            )
            .await?;

        // 删除 priority 字段
        manager
            .alter_table(
                Table::alter()
                    .table(NotificationLogs::Table)
                    .drop_column(NotificationLogs::Priority)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
