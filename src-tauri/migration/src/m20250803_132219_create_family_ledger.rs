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
                            .text()
                            .not_null()
                            .check(Expr::cust("LENGTH(description) <= 1000")),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::BaseCurrency)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(base_currency) <= 10")),
                    )
                    .col(ColumnDef::new(FamilyLedger::Members).string())
                    .col(ColumnDef::new(FamilyLedger::Accounts).string())
                    .col(ColumnDef::new(FamilyLedger::Transactions).string())
                    .col(ColumnDef::new(FamilyLedger::Budgets).string())
                    .col(ColumnDef::new(FamilyLedger::AuditLogs).string().not_null())
                    .col(ColumnDef::new(FamilyLedger::CreatedAt).string().not_null())
                    .col(ColumnDef::new(FamilyLedger::UpdatedAt).string())
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
