use sea_orm_migration::{prelude::*, schema::*};

use crate::schema::{NotificationReminderHistory, NotificationReminderState};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 1. 创建 notification_reminder_states 表
        manager
            .create_table(
                Table::create()
                    .table(NotificationReminderState::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(NotificationReminderState::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        string(NotificationReminderState::ReminderType)
                            .not_null()
                            .comment("提醒类型: todo, bill, period"),
                    )
                    .col(
                        ColumnDef::new(NotificationReminderState::ReminderSerialNum)
                            .string_len(38)
                            .not_null()
                            .comment("关联的提醒记录序列号"),
                    )
                    .col(
                        string(NotificationReminderState::NotificationType)
                            .not_null()
                            .comment("通知类型: TodoReminder, BillReminder, PeriodReminder, etc."),
                    )
                    .col(
                        timestamp_with_time_zone_null(NotificationReminderState::NextScheduledAt)
                            .comment("下次计划发送时间"),
                    )
                    .col(
                        timestamp_with_time_zone_null(NotificationReminderState::LastSentAt)
                            .comment("上次发送时间"),
                    )
                    .col(
                        timestamp_with_time_zone_null(NotificationReminderState::SnoozeUntil)
                            .comment("推迟到指定时间"),
                    )
                    .col(
                        string(NotificationReminderState::Status)
                            .not_null()
                            .default("pending")
                            .comment("状态: pending, sent, failed, snoozed, cancelled, expired"),
                    )
                    .col(
                        integer(NotificationReminderState::RetryCount)
                            .not_null()
                            .default(0)
                            .comment("重试次数"),
                    )
                    .col(string_null(NotificationReminderState::FailReason).comment("失败原因"))
                    .col(
                        integer(NotificationReminderState::SentCount)
                            .not_null()
                            .default(0)
                            .comment("已发送次数"),
                    )
                    .col(
                        integer(NotificationReminderState::ViewCount)
                            .not_null()
                            .default(0)
                            .comment("查看次数"),
                    )
                    .col(
                        integer_null(NotificationReminderState::ResponseTime)
                            .comment("响应时间（毫秒）"),
                    )
                    .col(
                        timestamp_with_time_zone(NotificationReminderState::CreatedAt)
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        timestamp_with_time_zone(NotificationReminderState::UpdatedAt)
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建唯一索引：reminder_type + reminder_serial_num
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_states_unique")
                    .table(NotificationReminderState::Table)
                    .col(NotificationReminderState::ReminderType)
                    .col(NotificationReminderState::ReminderSerialNum)
                    .unique()
                    .to_owned(),
            )
            .await?;

        // 创建索引：reminder_type (用于按类型查询)
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_states_type")
                    .table(NotificationReminderState::Table)
                    .col(NotificationReminderState::ReminderType)
                    .to_owned(),
            )
            .await?;

        // 创建索引：status (用于查询待处理/失败的提醒)
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_states_status")
                    .table(NotificationReminderState::Table)
                    .col(NotificationReminderState::Status)
                    .to_owned(),
            )
            .await?;

        // 创建索引：next_scheduled_at (用于扫描待执行提醒)
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_states_next_scheduled")
                    .table(NotificationReminderState::Table)
                    .col(NotificationReminderState::NextScheduledAt)
                    .to_owned(),
            )
            .await?;

        // 创建索引：notification_type (用于按通知类型统计)
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_states_notification_type")
                    .table(NotificationReminderState::Table)
                    .col(NotificationReminderState::NotificationType)
                    .to_owned(),
            )
            .await?;

        // 2. 创建 notification_reminder_history 表
        manager
            .create_table(
                Table::create()
                    .table(NotificationReminderHistory::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(NotificationReminderHistory::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(NotificationReminderHistory::ReminderStateSerialNum)
                            .string_len(38)
                            .not_null()
                            .comment("关联 reminder_states.serial_num"),
                    )
                    .col(
                        string(NotificationReminderHistory::ReminderType)
                            .not_null()
                            .comment("提醒类型"),
                    )
                    .col(
                        ColumnDef::new(NotificationReminderHistory::ReminderSerialNum)
                            .string_len(38)
                            .not_null()
                            .comment("提醒记录序列号"),
                    )
                    .col(
                        timestamp_with_time_zone(NotificationReminderHistory::SentAt)
                            .not_null()
                            .comment("发送时间"),
                    )
                    .col(
                        string(NotificationReminderHistory::SentMethods)
                            .not_null()
                            .comment("发送方式 (JSON数组)"),
                    )
                    .col(
                        string_null(NotificationReminderHistory::SentChannels)
                            .comment("实际发送的渠道 (JSON数组)"),
                    )
                    .col(
                        string(NotificationReminderHistory::Status)
                            .not_null()
                            .comment("状态: sent, failed, viewed, dismissed"),
                    )
                    .col(string_null(NotificationReminderHistory::FailReason).comment("失败原因"))
                    .col(
                        timestamp_with_time_zone_null(NotificationReminderHistory::ViewedAt)
                            .comment("查看时间"),
                    )
                    .col(
                        timestamp_with_time_zone_null(NotificationReminderHistory::DismissedAt)
                            .comment("关闭时间"),
                    )
                    .col(
                        string_null(NotificationReminderHistory::ActionTaken)
                            .comment("用户操作: none, completed, snoozed, dismissed"),
                    )
                    .col(
                        string_null(NotificationReminderHistory::UserLocation)
                            .comment("用户位置 (JSON)"),
                    )
                    .col(
                        string_null(NotificationReminderHistory::DeviceInfo)
                            .comment("设备信息 (JSON)"),
                    )
                    .col(
                        timestamp_with_time_zone(NotificationReminderHistory::CreatedAt)
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_reminder_history_state")
                            .from(
                                NotificationReminderHistory::Table,
                                NotificationReminderHistory::ReminderStateSerialNum,
                            )
                            .to(
                                NotificationReminderState::Table,
                                NotificationReminderState::SerialNum,
                            )
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引：reminder_state_serial_num (用于查询某个提醒的历史)
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_history_state")
                    .table(NotificationReminderHistory::Table)
                    .col(NotificationReminderHistory::ReminderStateSerialNum)
                    .to_owned(),
            )
            .await?;

        // 创建索引：sent_at (用于时间范围查询)
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_history_sent_at")
                    .table(NotificationReminderHistory::Table)
                    .col(NotificationReminderHistory::SentAt)
                    .to_owned(),
            )
            .await?;

        // 创建索引：status (用于查询失败记录)
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_history_status")
                    .table(NotificationReminderHistory::Table)
                    .col(NotificationReminderHistory::Status)
                    .to_owned(),
            )
            .await?;

        // 创建复合索引：reminder_type + reminder_serial_num (用于查询特定提醒的历史)
        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_history_type_id")
                    .table(NotificationReminderHistory::Table)
                    .col(NotificationReminderHistory::ReminderType)
                    .col(NotificationReminderHistory::ReminderSerialNum)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除表（先删除有外键的表）
        manager
            .drop_table(
                Table::drop()
                    .table(NotificationReminderHistory::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(
                Table::drop()
                    .table(NotificationReminderState::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
