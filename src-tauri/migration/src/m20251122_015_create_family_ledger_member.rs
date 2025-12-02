use sea_orm_migration::prelude::*;

use crate::schema::{FamilyLedger, FamilyLedgerMember, FamilyMember};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 family_ledger_member 关联表
        manager
            .create_table(
                Table::create()
                    .table(FamilyLedgerMember::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FamilyLedgerMember::FamilyLedgerSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerMember::FamilyMemberSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerMember::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerMember::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .primary_key(
                        Index::create()
                            .col(FamilyLedgerMember::FamilyLedgerSerialNum)
                            .col(FamilyLedgerMember::FamilyMemberSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_member_ledger")
                            .from(
                                FamilyLedgerMember::Table,
                                FamilyLedgerMember::FamilyLedgerSerialNum,
                            )
                            .to(FamilyLedger::Table, FamilyLedger::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_member_member")
                            .from(
                                FamilyLedgerMember::Table,
                                FamilyLedgerMember::FamilyMemberSerialNum,
                            )
                            .to(FamilyMember::Table, FamilyMember::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_family_ledger_member_ledger")
                    .table(FamilyLedgerMember::Table)
                    .col(FamilyLedgerMember::FamilyLedgerSerialNum)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_family_ledger_member_member")
                    .table(FamilyLedgerMember::Table)
                    .col(FamilyLedgerMember::FamilyMemberSerialNum)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_ledger_member_member")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_ledger_member_ledger")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(FamilyLedgerMember::Table).to_owned())
            .await?;

        Ok(())
    }
}
