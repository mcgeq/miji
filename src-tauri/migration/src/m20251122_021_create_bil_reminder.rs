use sea_orm_migration::prelude::*;
use crate::schema::{BilReminder, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 bil_reminder 表 - 整合了3个源文件的所有字段
        manager.create_table(Table::create().table(BilReminder::Table).if_not_exists()
            // 基础字段
            .col(ColumnDef::new(BilReminder::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(BilReminder::Name).string().not_null())
            .col(ColumnDef::new(BilReminder::Enabled).boolean().not_null().default(true))
            .col(ColumnDef::new(BilReminder::Type).string().not_null())
            .col(ColumnDef::new(BilReminder::Description).string_len(1000).null())
            .col(ColumnDef::new(BilReminder::Category).string().not_null())
            .col(ColumnDef::new(BilReminder::Amount).decimal_len(16, 4).default(0.0))
            .col(ColumnDef::new(BilReminder::Currency).string_len(3).null())
            .col(ColumnDef::new(BilReminder::DueAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(BilReminder::BillDate).timestamp_with_time_zone().null())
            .col(ColumnDef::new(BilReminder::RemindDate).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(BilReminder::RepeatPeriod).json_binary().not_null())
            .col(ColumnDef::new(BilReminder::RepeatPeriodType).string().null())
            .col(ColumnDef::new(BilReminder::IsPaid).boolean().not_null().default(false))
            .col(ColumnDef::new(BilReminder::Priority).string().not_null().default("Low"))
            .col(ColumnDef::new(BilReminder::AdvanceValue).integer().null())
            .col(ColumnDef::new(BilReminder::AdvanceUnit).string().null())
            .col(ColumnDef::new(BilReminder::RelatedTransactionSerialNum).string_len(38).null())
            .col(ColumnDef::new(BilReminder::Color).string().null())
            .col(ColumnDef::new(BilReminder::IsDeleted).boolean().not_null().default(false))
            // 提醒扩展字段 (来自 enhance_bil_reminder_fields)
            .col(ColumnDef::new(BilReminder::LastReminderSentAt).timestamp_with_time_zone().null())
            .col(ColumnDef::new(BilReminder::ReminderFrequency).string_len(20).null().default("once"))
            .col(ColumnDef::new(BilReminder::SnoozeUntil).timestamp_with_time_zone().null())
            .col(ColumnDef::new(BilReminder::ReminderMethods).json_binary().null())
            .col(ColumnDef::new(BilReminder::EscalationEnabled).boolean().not_null().default(false))
            .col(ColumnDef::new(BilReminder::EscalationAfterHours).integer().null())
            .col(ColumnDef::new(BilReminder::Timezone).string_len(50).null().default("UTC"))
            .col(ColumnDef::new(BilReminder::SmartReminderEnabled).boolean().not_null().default(false))
            .col(ColumnDef::new(BilReminder::AutoReschedule).boolean().not_null().default(false))
            .col(ColumnDef::new(BilReminder::PaymentReminderEnabled).boolean().not_null().default(false))
            .col(ColumnDef::new(BilReminder::BatchReminderId).string_len(38).null())
            // 时间戳
            .col(ColumnDef::new(BilReminder::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(BilReminder::UpdatedAt).timestamp_with_time_zone().null())
            // 外键约束
            .foreign_key(ForeignKey::create().name("fk_bil_reminder_transaction")
                .from(BilReminder::Table, BilReminder::RelatedTransactionSerialNum)
                .to(Transactions::Table, Transactions::SerialNum).on_delete(ForeignKeyAction::Restrict))
            .to_owned()).await?;
        
        // 创建索引
        manager.create_index(Index::create().name("idx_bil_reminder_due_at").table(BilReminder::Table).col(BilReminder::DueAt).to_owned()).await?;
        manager.create_index(Index::create().name("idx_bil_reminder_paid").table(BilReminder::Table).col(BilReminder::IsPaid).to_owned()).await?;
        manager.create_index(Index::create().name("idx_bil_reminder_snooze").table(BilReminder::Table).col(BilReminder::SnoozeUntil).to_owned()).await?;
        manager.create_index(Index::create().name("idx_bil_reminder_batch").table(BilReminder::Table).col(BilReminder::BatchReminderId).to_owned()).await?;
        Ok(())
    }
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(BilReminder::Table).to_owned()).await
    }
}
