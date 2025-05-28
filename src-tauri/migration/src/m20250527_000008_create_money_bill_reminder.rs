use sea_orm_migration::prelude::*;

use crate::money_scheme::{BilReminder, Transaction};

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
                    .col(ColumnDef::new(BilReminder::Amount).decimal().not_null())
                    .col(ColumnDef::new(BilReminder::DueDate).date().not_null())
                    .col(
                        ColumnDef::new(BilReminder::RepeatPeriod)
                            .tiny_integer()
                            .not_null()
                            .check(Expr::col(BilReminder::RepeatPeriod).is_in([0, 1, 2, 3, 4]))
                            .default(0),
                    )
                    .col(ColumnDef::new(BilReminder::IsPaid).boolean().not_null())
                    .col(
                        ColumnDef::new(BilReminder::RelatedTransactionSerialNum)
                            .string_len(38)
                            .null(),
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
                            .from(BilReminder::Table, BilReminder::RelatedTransactionSerialNum)
                            .to(Transaction::Table, Transaction::SerialNum),
                    )
                    .to_owned(),
            )
            .await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(BilReminder::Table).to_owned())
            .await?;
        Ok(())
    }
}
