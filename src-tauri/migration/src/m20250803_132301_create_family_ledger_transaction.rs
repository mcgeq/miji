use sea_orm_migration::prelude::*;

use crate::schema::{FamilyLedger, FamilyLedgerTransaction, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(FamilyLedgerTransaction::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FamilyLedgerTransaction::FamilyLedgerSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerTransaction::TransactionSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerTransaction::CreatedAt)
                            .string()
                            .not_null(),
                    )
                    .col(ColumnDef::new(FamilyLedgerTransaction::UpdatedAt).string())
                    .primary_key(
                        Index::create()
                            .col(FamilyLedgerTransaction::FamilyLedgerSerialNum)
                            .col(FamilyLedgerTransaction::TransactionSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_transaction_ledger")
                            .from(
                                FamilyLedgerTransaction::Table,
                                FamilyLedgerTransaction::FamilyLedgerSerialNum,
                            )
                            .to(FamilyLedger::Table, FamilyLedger::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_transaction_transaction")
                            .from(
                                FamilyLedgerTransaction::Table,
                                FamilyLedgerTransaction::TransactionSerialNum,
                            )
                            .to(Transactions::Table, Transactions::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_family_ledger_transaction_ledger")
                    .table(FamilyLedgerTransaction::Table)
                    .col(FamilyLedgerTransaction::FamilyLedgerSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_family_ledger_transaction_transaction")
                    .table(FamilyLedgerTransaction::Table)
                    .col(FamilyLedgerTransaction::TransactionSerialNum)
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
                    .name("idx_family_ledger_transaction_ledger")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_ledger_transaction_transaction")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(
                Table::drop()
                    .table(FamilyLedgerTransaction::Table)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
