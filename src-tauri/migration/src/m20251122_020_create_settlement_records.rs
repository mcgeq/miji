use sea_orm_migration::prelude::*;
use crate::schema::{FamilyLedger, FamilyMember, SettlementRecords};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.create_table(Table::create().table(SettlementRecords::Table).if_not_exists()
            .col(ColumnDef::new(SettlementRecords::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(SettlementRecords::FamilyLedgerSerialNum).string_len(38).not_null())
            .col(ColumnDef::new(SettlementRecords::SettlementType).string_len(20).not_null()
                .check(Expr::col(SettlementRecords::SettlementType).is_in(vec!["Manual", "Automatic", "Partial", "Full"])))
            .col(ColumnDef::new(SettlementRecords::PeriodStart).date().not_null())
            .col(ColumnDef::new(SettlementRecords::PeriodEnd).date().not_null())
            .col(ColumnDef::new(SettlementRecords::TotalAmount).decimal_len(15, 2).not_null().default(0.00))
            .col(ColumnDef::new(SettlementRecords::Currency).string_len(3).not_null().default("CNY"))
            .col(ColumnDef::new(SettlementRecords::ParticipantMembers).json().not_null())
            .col(ColumnDef::new(SettlementRecords::SettlementDetails).json().not_null())
            .col(ColumnDef::new(SettlementRecords::OptimizedTransfers).json().null())
            .col(ColumnDef::new(SettlementRecords::Status).string_len(20).not_null().default("Pending")
                .check(Expr::col(SettlementRecords::Status).is_in(vec!["Pending", "InProgress", "Completed", "Cancelled"])))
            .col(ColumnDef::new(SettlementRecords::InitiatedBy).string_len(38).not_null())
            .col(ColumnDef::new(SettlementRecords::CompletedBy).string_len(38).null())
            .col(ColumnDef::new(SettlementRecords::Description).string_len(500).null())
            .col(ColumnDef::new(SettlementRecords::Notes).text().null())
            .col(ColumnDef::new(SettlementRecords::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(SettlementRecords::UpdatedAt).timestamp_with_time_zone().null())
            .foreign_key(ForeignKey::create().name("fk_settlement_ledger")
                .from(SettlementRecords::Table, SettlementRecords::FamilyLedgerSerialNum)
                .to(FamilyLedger::Table, FamilyLedger::SerialNum).on_delete(ForeignKeyAction::Cascade))
            .foreign_key(ForeignKey::create().name("fk_settlement_initiated_by")
                .from(SettlementRecords::Table, SettlementRecords::InitiatedBy)
                .to(FamilyMember::Table, FamilyMember::SerialNum).on_delete(ForeignKeyAction::Restrict))
            .to_owned()).await?;
        
        manager.create_index(Index::create().name("idx_settlement_ledger").table(SettlementRecords::Table).col(SettlementRecords::FamilyLedgerSerialNum).to_owned()).await?;
        manager.create_index(Index::create().name("idx_settlement_status").table(SettlementRecords::Table).col(SettlementRecords::Status).to_owned()).await?;
        Ok(())
    }
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(SettlementRecords::Table).to_owned()).await
    }
}
