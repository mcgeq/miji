use sea_orm_migration::prelude::*;

use crate::schema::BilReminder;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加高级提醒功能字段到bil_reminder表 - 需要分别执行，因为SQLite不支持单个ALTER TABLE添加多个字段
        
        // 1. 添加 last_reminder_sent_at 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::LastReminderSentAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 2. 添加 reminder_frequency 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::ReminderFrequency)
                            .string_len(20)
                            .null()
                            .default("once"),
                    )
                    .to_owned(),
            )
            .await?;

        // 3. 添加 snooze_until 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::SnoozeUntil)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 4. 添加 reminder_methods 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::ReminderMethods)
                            .json_binary()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 5. 添加 escalation_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::EscalationEnabled)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .to_owned(),
            )
            .await?;

        // 6. 添加 escalation_after_hours 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::EscalationAfterHours)
                            .integer()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 7. 添加 timezone 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::Timezone)
                            .string_len(50)
                            .null()
                            .default("UTC"),
                    )
                    .to_owned(),
            )
            .await?;

        // 8. 添加 smart_reminder_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::SmartReminderEnabled)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .to_owned(),
            )
            .await?;

        // 9. 添加 auto_reschedule 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::AutoReschedule)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .to_owned(),
            )
            .await?;

        // 10. 添加 payment_reminder_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::PaymentReminderEnabled)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .to_owned(),
            )
            .await?;

        // 11. 添加 batch_reminder_id 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .add_column(
                        ColumnDef::new(BilReminder::BatchReminderId)
                            .string_len(38)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建相关索引
        manager
            .create_index(
                Index::create()
                    .name("idx_bil_reminder_scan")
                    .table(BilReminder::Table)
                    .col(BilReminder::Enabled)
                    .col(BilReminder::RemindDate)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_bil_reminder_escalation")
                    .table(BilReminder::Table)
                    .col(BilReminder::EscalationEnabled)
                    .col(BilReminder::LastReminderSentAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_bil_reminder_snooze")
                    .table(BilReminder::Table)
                    .col(BilReminder::SnoozeUntil)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_bil_reminder_batch")
                    .table(BilReminder::Table)
                    .col(BilReminder::BatchReminderId)
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
                    .name("idx_bil_reminder_scan")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_bil_reminder_escalation")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_bil_reminder_snooze")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_bil_reminder_batch")
                    .to_owned(),
            )
            .await?;

        // 删除添加的字段 - 需要分别执行，因为SQLite不支持单个ALTER TABLE删除多个字段
        
        // 11. 删除 batch_reminder_id 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::BatchReminderId)
                    .to_owned(),
            )
            .await?;

        // 10. 删除 payment_reminder_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::PaymentReminderEnabled)
                    .to_owned(),
            )
            .await?;

        // 9. 删除 auto_reschedule 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::AutoReschedule)
                    .to_owned(),
            )
            .await?;

        // 8. 删除 smart_reminder_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::SmartReminderEnabled)
                    .to_owned(),
            )
            .await?;

        // 7. 删除 timezone 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::Timezone)
                    .to_owned(),
            )
            .await?;

        // 6. 删除 escalation_after_hours 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::EscalationAfterHours)
                    .to_owned(),
            )
            .await?;

        // 5. 删除 escalation_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::EscalationEnabled)
                    .to_owned(),
            )
            .await?;

        // 4. 删除 reminder_methods 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::ReminderMethods)
                    .to_owned(),
            )
            .await?;

        // 3. 删除 snooze_until 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::SnoozeUntil)
                    .to_owned(),
            )
            .await?;

        // 2. 删除 reminder_frequency 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::ReminderFrequency)
                    .to_owned(),
            )
            .await?;

        // 1. 删除 last_reminder_sent_at 字段
        manager
            .alter_table(
                Table::alter()
                    .table(BilReminder::Table)
                    .drop_column(BilReminder::LastReminderSentAt)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}

