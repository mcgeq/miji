use sea_orm_migration::prelude::*;
use crate::schema::{FamilyLedger, FamilyMember, SplitRecords, SplitRules, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.create_table(
            Table::create()
                .table(SplitRecords::Table)
                .if_not_exists()
                .col(ColumnDef::new(SplitRecords::SerialNum).string_len(38).not_null().primary_key())
                .col(ColumnDef::new(SplitRecords::TransactionSerialNum).string_len(38).not_null())
                .col(ColumnDef::new(SplitRecords::FamilyLedgerSerialNum).string_len(38).not_null())
                .col(ColumnDef::new(SplitRecords::SplitRuleSerialNum).string_len(38).null())
                .col(ColumnDef::new(SplitRecords::PayerMemberSerialNum).string_len(38).not_null())
                .col(ColumnDef::new(SplitRecords::OweMemberSerialNum).string_len(38).not_null())
                .col(ColumnDef::new(SplitRecords::TotalAmount).decimal_len(15, 2).not_null())
                .col(ColumnDef::new(SplitRecords::SplitAmount).decimal_len(15, 2).not_null())
                .col(ColumnDef::new(SplitRecords::SplitPercentage).decimal_len(5, 2).null())
                .col(ColumnDef::new(SplitRecords::Currency).string_len(3).not_null().default("CNY"))
                .col(ColumnDef::new(SplitRecords::Status).string_len(20).not_null().default("Pending")
                    .check(Expr::col(SplitRecords::Status).is_in(vec!["Pending", "Confirmed", "Paid", "Cancelled"])))
                .col(ColumnDef::new(SplitRecords::SplitType).string_len(20).not_null()
                    .check(Expr::col(SplitRecords::SplitType).is_in(vec!["Equal", "Percentage", "FixedAmount", "Weighted"])))
                .col(ColumnDef::new(SplitRecords::Description).string_len(500).null())
                .col(ColumnDef::new(SplitRecords::Notes).text().null())
                .col(ColumnDef::new(SplitRecords::ConfirmedAt).timestamp_with_time_zone().null())
                .col(ColumnDef::new(SplitRecords::PaidAt).timestamp_with_time_zone().null())
                .col(ColumnDef::new(SplitRecords::DueDate).date().null())
                .col(ColumnDef::new(SplitRecords::ReminderSent).boolean().not_null().default(false))
                .col(ColumnDef::new(SplitRecords::LastReminderAt).timestamp_with_time_zone().null())
                .col(ColumnDef::new(SplitRecords::CreatedAt).timestamp_with_time_zone().not_null())
                .col(ColumnDef::new(SplitRecords::UpdatedAt).timestamp_with_time_zone().null())
                .foreign_key(ForeignKey::create().name("fk_split_records_transaction")
                    .from(SplitRecords::Table, SplitRecords::TransactionSerialNum)
                    .to(Transactions::Table, Transactions::SerialNum)
                    .on_delete(ForeignKeyAction::Cascade).on_update(ForeignKeyAction::Cascade))
                .foreign_key(ForeignKey::create().name("fk_split_records_family_ledger")
                    .from(SplitRecords::Table, SplitRecords::FamilyLedgerSerialNum)
                    .to(FamilyLedger::Table, FamilyLedger::SerialNum)
                    .on_delete(ForeignKeyAction::Cascade).on_update(ForeignKeyAction::Cascade))
                .foreign_key(ForeignKey::create().name("fk_split_records_split_rule")
                    .from(SplitRecords::Table, SplitRecords::SplitRuleSerialNum)
                    .to(SplitRules::Table, SplitRules::SerialNum)
                    .on_delete(ForeignKeyAction::SetNull).on_update(ForeignKeyAction::Cascade))
                .foreign_key(ForeignKey::create().name("fk_split_records_payer")
                    .from(SplitRecords::Table, SplitRecords::PayerMemberSerialNum)
                    .to(FamilyMember::Table, FamilyMember::SerialNum)
                    .on_delete(ForeignKeyAction::Restrict).on_update(ForeignKeyAction::Cascade))
                .foreign_key(ForeignKey::create().name("fk_split_records_owe")
                    .from(SplitRecords::Table, SplitRecords::OweMemberSerialNum)
                    .to(FamilyMember::Table, FamilyMember::SerialNum)
                    .on_delete(ForeignKeyAction::Restrict).on_update(ForeignKeyAction::Cascade))
                .to_owned(),
        ).await?;
        
        manager.create_index(Index::create().name("idx_split_records_transaction").table(SplitRecords::Table).col(SplitRecords::TransactionSerialNum).to_owned()).await?;
        manager.create_index(Index::create().name("idx_split_records_ledger").table(SplitRecords::Table).col(SplitRecords::FamilyLedgerSerialNum).to_owned()).await?;
        manager.create_index(Index::create().name("idx_split_records_payer").table(SplitRecords::Table).col(SplitRecords::PayerMemberSerialNum).to_owned()).await?;
        manager.create_index(Index::create().name("idx_split_records_owe").table(SplitRecords::Table).col(SplitRecords::OweMemberSerialNum).to_owned()).await?;
        manager.create_index(Index::create().name("idx_split_records_status").table(SplitRecords::Table).col(SplitRecords::Status).to_owned()).await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(SplitRecords::Table).to_owned()).await
    }
}
