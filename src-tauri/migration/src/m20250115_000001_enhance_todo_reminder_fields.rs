use sea_orm_migration::prelude::*;

use crate::schema::Todo;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加提醒相关字段到todos表 - 需要分别执行，因为SQLite不支持单个ALTER TABLE添加多个字段
        
        // 1. 添加 reminder_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::ReminderEnabled)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .to_owned(),
            )
            .await?;

        // 2. 添加 reminder_advance_value 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::ReminderAdvanceValue)
                            .integer()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 3. 添加 reminder_advance_unit 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::ReminderAdvanceUnit)
                            .string_len(20)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 4. 添加 last_reminder_sent_at 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::LastReminderSentAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 5. 添加 reminder_frequency 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::ReminderFrequency)
                            .string_len(20)
                            .null()
                            .default("once"),
                    )
                    .to_owned(),
            )
            .await?;

        // 6. 添加 snooze_until 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::SnoozeUntil)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 7. 添加 reminder_methods 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::ReminderMethods)
                            .json_binary()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 8. 添加 timezone 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::Timezone)
                            .string_len(50)
                            .null()
                            .default("UTC"),
                    )
                    .to_owned(),
            )
            .await?;

        // 9. 添加 smart_reminder_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::SmartReminderEnabled)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .to_owned(),
            )
            .await?;

        // 10. 添加 location_based_reminder 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::LocationBasedReminder)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .to_owned(),
            )
            .await?;

        // 11. 添加 weather_dependent 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::WeatherDependent)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .to_owned(),
            )
            .await?;

        // 12. 添加 priority_boost_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::PriorityBoostEnabled)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .to_owned(),
            )
            .await?;

        // 13. 添加 batch_reminder_id 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .add_column(
                        ColumnDef::new(Todo::BatchReminderId)
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
                    .name("idx_todo_reminder_scan")
                    .table(Todo::Table)
                    .col(Todo::ReminderEnabled)
                    .col(Todo::DueAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_snooze")
                    .table(Todo::Table)
                    .col(Todo::SnoozeUntil)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_batch_reminder")
                    .table(Todo::Table)
                    .col(Todo::BatchReminderId)
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
                    .name("idx_todo_reminder_scan")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_todo_snooze")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_todo_batch_reminder")
                    .to_owned(),
            )
            .await?;

        // 删除添加的字段 - 需要分别执行，因为SQLite不支持单个ALTER TABLE删除多个字段
        
        // 13. 删除 batch_reminder_id 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::BatchReminderId)
                    .to_owned(),
            )
            .await?;

        // 12. 删除 priority_boost_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::PriorityBoostEnabled)
                    .to_owned(),
            )
            .await?;

        // 11. 删除 weather_dependent 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::WeatherDependent)
                    .to_owned(),
            )
            .await?;

        // 10. 删除 location_based_reminder 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::LocationBasedReminder)
                    .to_owned(),
            )
            .await?;

        // 9. 删除 smart_reminder_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::SmartReminderEnabled)
                    .to_owned(),
            )
            .await?;

        // 8. 删除 timezone 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::Timezone)
                    .to_owned(),
            )
            .await?;

        // 7. 删除 reminder_methods 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::ReminderMethods)
                    .to_owned(),
            )
            .await?;

        // 6. 删除 snooze_until 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::SnoozeUntil)
                    .to_owned(),
            )
            .await?;

        // 5. 删除 reminder_frequency 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::ReminderFrequency)
                    .to_owned(),
            )
            .await?;

        // 4. 删除 last_reminder_sent_at 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::LastReminderSentAt)
                    .to_owned(),
            )
            .await?;

        // 3. 删除 reminder_advance_unit 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::ReminderAdvanceUnit)
                    .to_owned(),
            )
            .await?;

        // 2. 删除 reminder_advance_value 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::ReminderAdvanceValue)
                    .to_owned(),
            )
            .await?;

        // 1. 删除 reminder_enabled 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::ReminderEnabled)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}

