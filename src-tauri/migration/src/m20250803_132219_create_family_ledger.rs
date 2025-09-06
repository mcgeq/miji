use sea_orm_migration::prelude::*;

use crate::schema::{Currency, FamilyLedger};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(FamilyLedger::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FamilyLedger::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(FamilyLedger::Name).string())
                    .col(
                        ColumnDef::new(FamilyLedger::Description)
                            .string_len(1000)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::BaseCurrency)
                            .string_len(3)
                            .not_null(),
                    )
                    .col(ColumnDef::new(FamilyLedger::Members).string())
                    .col(ColumnDef::new(FamilyLedger::Accounts).string())
                    .col(ColumnDef::new(FamilyLedger::Transactions).string())
                    .col(ColumnDef::new(FamilyLedger::Budgets).string())
                    .col(ColumnDef::new(FamilyLedger::AuditLogs).string().not_null())
                    .col(
                        ColumnDef::new(FamilyLedger::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_currency")
                            .from(FamilyLedger::Table, FamilyLedger::BaseCurrency)
                            .to(Currency::Table, Currency::Code)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(FamilyLedger::Table).to_owned())
            .await?;

        Ok(())
    }
}
