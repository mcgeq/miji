use sea_orm_migration::prelude::*;

use crate::money_scheme::{Currency, FamilyLedger};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(FamilyLedger::Table)
                    .col(
                        ColumnDef::new(FamilyLedger::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Description)
                            .string()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::BaseCurrency)
                            .string()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Members)
                            .json_binary()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Accounts)
                            .json_binary()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Transactions)
                            .json_binary()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Budgets)
                            .json_binary()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::AuditLogs)
                            .json_binary()
                            .not_null(),
                    )
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
                            .from(FamilyLedger::Table, FamilyLedger::BaseCurrency)
                            .to(Currency::Table, Currency::Code),
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
