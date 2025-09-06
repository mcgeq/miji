use sea_orm_migration::prelude::*;

use crate::schema::{Account, FamilyLedger, FamilyLedgerAccount};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(FamilyLedgerAccount::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FamilyLedgerAccount::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerAccount::FamilyLedgerSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerAccount::AccountSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerAccount::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerAccount::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_account_ledger")
                            .from(
                                FamilyLedgerAccount::Table,
                                FamilyLedgerAccount::FamilyLedgerSerialNum,
                            )
                            .to(FamilyLedger::Table, FamilyLedger::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_account_account")
                            .from(
                                FamilyLedgerAccount::Table,
                                FamilyLedgerAccount::AccountSerialNum,
                            )
                            .to(Account::Table, Account::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_family_ledger_account_ledger")
                    .table(FamilyLedgerAccount::Table)
                    .col(FamilyLedgerAccount::FamilyLedgerSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_family_ledger_account_account")
                    .table(FamilyLedgerAccount::Table)
                    .col(FamilyLedgerAccount::AccountSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_ledger_account_ledger")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_ledger_account_account")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(Table::drop().table(FamilyLedgerAccount::Table).to_owned())
            .await?;

        Ok(())
    }
}
