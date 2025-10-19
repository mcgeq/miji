use sea_orm_migration::prelude::*;

use crate::schema::Reminder;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加提醒执行相关字段到reminder表 - 需要分别执行，因为SQLite不支持单个ALTER TABLE添加多个字段

        // 1. 添加 reminder_method 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .add_column(
                        ColumnDef::new(Reminder::ReminderMethod)
                            .string_len(20)
                            .null()
                            .default("desktop"),
                    )
                    .to_owned(),
            )
            .await?;

        // 2. 添加 retry_count 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .add_column(
                        ColumnDef::new(Reminder::RetryCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .to_owned(),
            )
            .await?;

        // 3. 添加 last_retry_at 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .add_column(
                        ColumnDef::new(Reminder::LastRetryAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 4. 添加 snooze_count 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .add_column(
                        ColumnDef::new(Reminder::SnoozeCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .to_owned(),
            )
            .await?;

        // 5. 添加 escalation_level 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .add_column(
                        ColumnDef::new(Reminder::EscalationLevel)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .to_owned(),
            )
            .await?;

        // 6. 添加 notification_id 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .add_column(
                        ColumnDef::new(Reminder::NotificationId)
                            .string_len(100)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建相关索引
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_status")
                    .table(Reminder::Table)
                    .col(Reminder::IsSent)
                    .col(Reminder::RemindAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_retry")
                    .table(Reminder::Table)
                    .col(Reminder::RetryCount)
                    .col(Reminder::LastRetryAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_escalation")
                    .table(Reminder::Table)
                    .col(Reminder::EscalationLevel)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除索引
        manager
            .drop_index(Index::drop().name("idx_reminder_status").to_owned())
            .await?;

        manager
            .drop_index(Index::drop().name("idx_reminder_retry").to_owned())
            .await?;

        manager
            .drop_index(Index::drop().name("idx_reminder_escalation").to_owned())
            .await?;

        // 删除添加的字段 - 需要分别执行，因为SQLite不支持单个ALTER TABLE删除多个字段

        // 6. 删除 notification_id 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .drop_column(Reminder::NotificationId)
                    .to_owned(),
            )
            .await?;

        // 5. 删除 escalation_level 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .drop_column(Reminder::EscalationLevel)
                    .to_owned(),
            )
            .await?;

        // 4. 删除 snooze_count 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .drop_column(Reminder::SnoozeCount)
                    .to_owned(),
            )
            .await?;

        // 3. 删除 last_retry_at 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .drop_column(Reminder::LastRetryAt)
                    .to_owned(),
            )
            .await?;

        // 2. 删除 retry_count 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .drop_column(Reminder::RetryCount)
                    .to_owned(),
            )
            .await?;

        // 1. 删除 reminder_method 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Reminder::Table)
                    .drop_column(Reminder::ReminderMethod)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
