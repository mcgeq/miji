use sea_orm_migration::prelude::*;

use crate::schema::{NotificationLogs, NotificationSettings, BatchReminders};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建notification_logs表
        manager
            .create_table(
                Table::create()
                    .table(NotificationLogs::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(NotificationLogs::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::ReminderSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::NotificationType)
                            .string_len(20)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::Status)
                            .string_len(20)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::SentAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::ErrorMessage)
                            .text()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::RetryCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::LastRetryAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(NotificationLogs::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建notification_settings表
        manager
            .create_table(
                Table::create()
                    .table(NotificationSettings::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(NotificationSettings::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::UserId)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::NotificationType)
                            .string_len(20)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::Enabled)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::QuietHoursStart)
                            .time()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::QuietHoursEnd)
                            .time()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::QuietDays)
                            .json_binary()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::SoundEnabled)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::VibrationEnabled)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(NotificationSettings::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建batch_reminders表
        manager
            .create_table(
                Table::create()
                    .table(BatchReminders::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(BatchReminders::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::Name)
                            .string_len(100)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::Description)
                            .text()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::ScheduledAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::Status)
                            .string_len(20)
                            .not_null()
                            .default("pending"),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::TotalCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::SentCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::FailedCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BatchReminders::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_notification_logs_status")
                    .table(NotificationLogs::Table)
                    .col(NotificationLogs::Status)
                    .col(NotificationLogs::CreatedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_notification_logs_retry")
                    .table(NotificationLogs::Table)
                    .col(NotificationLogs::RetryCount)
                    .col(NotificationLogs::LastRetryAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_notification_settings_user")
                    .table(NotificationSettings::Table)
                    .col(NotificationSettings::UserId)
                    .col(NotificationSettings::NotificationType)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_batch_reminders_status")
                    .table(BatchReminders::Table)
                    .col(BatchReminders::Status)
                    .col(BatchReminders::ScheduledAt)
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
                    .name("idx_notification_logs_status")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_notification_logs_retry")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_notification_settings_user")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_batch_reminders_status")
                    .to_owned(),
            )
            .await?;

        // 删除表
        manager
            .drop_table(
                Table::drop()
                    .table(BatchReminders::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(
                Table::drop()
                    .table(NotificationSettings::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(
                Table::drop()
                    .table(NotificationLogs::Table)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}

