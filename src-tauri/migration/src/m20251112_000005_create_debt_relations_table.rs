use sea_orm_migration::prelude::*;

use crate::schema::{DebtRelations, FamilyLedger, FamilyMember};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(DebtRelations::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(DebtRelations::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::FamilyLedgerSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::CreditorMemberSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::DebtorMemberSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::Amount)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::Currency)
                            .string_len(3)
                            .not_null()
                            .default("CNY"),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::Status)
                            .string_len(20)
                            .not_null()
                            .default("Active")
                            .check(
                                Expr::col(DebtRelations::Status)
                                    .is_in(vec!["Active", "Settled", "Cancelled"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::LastUpdatedBy)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::LastCalculatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::SettledAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::Notes)
                            .text()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DebtRelations::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_debt_relations_family_ledger")
                            .from(DebtRelations::Table, DebtRelations::FamilyLedgerSerialNum)
                            .to(FamilyLedger::Table, FamilyLedger::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_debt_relations_creditor")
                            .from(DebtRelations::Table, DebtRelations::CreditorMemberSerialNum)
                            .to(FamilyMember::Table, FamilyMember::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_debt_relations_debtor")
                            .from(DebtRelations::Table, DebtRelations::DebtorMemberSerialNum)
                            .to(FamilyMember::Table, FamilyMember::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .index(
                        Index::create()
                            .name("idx_debt_relations_family_ledger")
                            .table(DebtRelations::Table)
                            .col(DebtRelations::FamilyLedgerSerialNum),
                    )
                    .index(
                        Index::create()
                            .name("idx_debt_relations_creditor")
                            .table(DebtRelations::Table)
                            .col(DebtRelations::CreditorMemberSerialNum),
                    )
                    .index(
                        Index::create()
                            .name("idx_debt_relations_debtor")
                            .table(DebtRelations::Table)
                            .col(DebtRelations::DebtorMemberSerialNum),
                    )
                    .index(
                        Index::create()
                            .name("idx_debt_relations_status")
                            .table(DebtRelations::Table)
                            .col(DebtRelations::Status),
                    )
                    .index(
                        Index::create()
                            .name("idx_debt_relations_unique_pair")
                            .table(DebtRelations::Table)
                            .col(DebtRelations::FamilyLedgerSerialNum)
                            .col(DebtRelations::CreditorMemberSerialNum)
                            .col(DebtRelations::DebtorMemberSerialNum)
                            .unique(),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(DebtRelations::Table).to_owned())
            .await?;

        Ok(())
    }
}
