use sea_orm_migration::prelude::*;
use crate::schema::{Reminder, Todo};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 reminder 表 - 整合了2个源文件的所有字段
        manager.create_table(Table::create().table(Reminder::Table).if_not_exists()
            // 基础字段
            .col(ColumnDef::new(Reminder::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(Reminder::TodoSerialNum).string_len(38).not_null())
            .col(ColumnDef::new(Reminder::RemindAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(Reminder::Type).string().not_null())
            .col(ColumnDef::new(Reminder::IsSent).boolean().not_null().default(false))
            // 执行扩展字段 (来自 enhance_reminder_fields)
            .col(ColumnDef::new(Reminder::ReminderMethod).string_len(20).null().default("desktop"))
            .col(ColumnDef::new(Reminder::RetryCount).integer().not_null().default(0))
            .col(ColumnDef::new(Reminder::LastRetryAt).timestamp_with_time_zone().null())
            .col(ColumnDef::new(Reminder::SnoozeCount).integer().not_null().default(0))
            .col(ColumnDef::new(Reminder::EscalationLevel).integer().not_null().default(0))
            .col(ColumnDef::new(Reminder::NotificationId).string_len(100).null())
            // 时间戳
            .col(ColumnDef::new(Reminder::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(Reminder::UpdatedAt).timestamp_with_time_zone().null())
            // 外键约束
            .foreign_key(ForeignKey::create().name("fk_reminder_todo")
                .from(Reminder::Table, Reminder::TodoSerialNum)
                .to(Todo::Table, Todo::SerialNum).on_delete(ForeignKeyAction::Cascade))
            .to_owned()).await?;
        
        // 创建索引
        manager.create_index(Index::create().name("idx_reminder_todo").table(Reminder::Table).col(Reminder::TodoSerialNum).to_owned()).await?;
        manager.create_index(Index::create().name("idx_reminder_time").table(Reminder::Table).col(Reminder::RemindAt).to_owned()).await?;
        manager.create_index(Index::create().name("idx_reminder_sent").table(Reminder::Table).col(Reminder::IsSent).to_owned()).await?;
        manager.create_index(Index::create().name("idx_reminder_method").table(Reminder::Table).col(Reminder::ReminderMethod).to_owned()).await?;
        Ok(())
    }
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(Reminder::Table).to_owned()).await
    }
}
