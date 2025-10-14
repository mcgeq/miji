use sea_orm_migration::{prelude::*, sea_orm::JsonValue};

use crate::schema::{BilReminder, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(BilReminder::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(BilReminder::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(BilReminder::Name).string().not_null())
                    .col(
                        ColumnDef::new(BilReminder::Enabled)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(ColumnDef::new(BilReminder::Type).string().not_null())
                    .col(
                        ColumnDef::new(BilReminder::Description)
                            .string_len(1000)
                            .null(),
                    )
                    .col(ColumnDef::new(BilReminder::Category).string().not_null())
                    .col(
                        ColumnDef::new(BilReminder::Amount)
                            .decimal_len(16, 4)
                            .default(0.0),
                    )
                    .col(ColumnDef::new(BilReminder::Currency).string_len(3).null())
                    .col(
                        ColumnDef::new(BilReminder::DueAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BilReminder::BillDate)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(BilReminder::RemindDate)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(JsonValue::Null),
                    )
                    .col(
                        ColumnDef::new(BilReminder::RepeatPeriod)
                            .json_binary()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BilReminder::IsPaid)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(BilReminder::Priority)
                            .string()
                            .not_null()
                            .default("Low"),
                    )
                    .col(ColumnDef::new(BilReminder::AdvanceValue).integer().null())
                    .col(ColumnDef::new(BilReminder::AdvanceUnit).string().null())
                    .col(
                        ColumnDef::new(BilReminder::RelatedTransactionSerialNum)
                            .string_len(38)
                            .null(),
                    )
                    .col(ColumnDef::new(BilReminder::Color).string().null())
                    .col(
                        ColumnDef::new(BilReminder::IsDeleted)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(BilReminder::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BilReminder::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_bil_reminder_transaction")
                            .from(BilReminder::Table, BilReminder::RelatedTransactionSerialNum)
                            .to(Transactions::Table, Transactions::SerialNum)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_bil_reminder_due_at")
                    .table(BilReminder::Table)
                    .col(BilReminder::DueAt)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_bil_reminder_paid")
                    .table(BilReminder::Table)
                    .col(BilReminder::IsPaid)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_bil_reminder_due_at").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_bil_reminder_paid").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(BilReminder::Table).to_owned())
            .await?;

        Ok(())
    }
}
