use sea_orm_migration::prelude::*;
use crate::schema::{FamilyMember, SplitRecordDetails, SplitRecords};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.create_table(
            Table::create()
                .table(SplitRecordDetails::Table)
                .if_not_exists()
                .col(ColumnDef::new(SplitRecordDetails::SerialNum).string_len(38).not_null().primary_key())
                .col(ColumnDef::new(SplitRecordDetails::SplitRecordSerialNum).string_len(38).not_null())
                .col(ColumnDef::new(SplitRecordDetails::MemberSerialNum).string_len(38).not_null())
                .col(ColumnDef::new(SplitRecordDetails::Amount).decimal_len(15, 2).not_null())
                .col(ColumnDef::new(SplitRecordDetails::Percentage).decimal_len(5, 2).null())
                .col(ColumnDef::new(SplitRecordDetails::Weight).integer().null())
                .col(ColumnDef::new(SplitRecordDetails::IsPaid).boolean().not_null().default(false))
                .col(ColumnDef::new(SplitRecordDetails::PaidAt).timestamp_with_time_zone().null())
                .col(ColumnDef::new(SplitRecordDetails::CreatedAt).timestamp_with_time_zone().not_null())
                .col(ColumnDef::new(SplitRecordDetails::UpdatedAt).timestamp_with_time_zone().null())
                .foreign_key(ForeignKey::create().name("fk_split_record_details_split_record")
                    .from(SplitRecordDetails::Table, SplitRecordDetails::SplitRecordSerialNum)
                    .to(SplitRecords::Table, SplitRecords::SerialNum)
                    .on_delete(ForeignKeyAction::Cascade).on_update(ForeignKeyAction::Cascade))
                .foreign_key(ForeignKey::create().name("fk_split_record_details_member")
                    .from(SplitRecordDetails::Table, SplitRecordDetails::MemberSerialNum)
                    .to(FamilyMember::Table, FamilyMember::SerialNum)
                    .on_delete(ForeignKeyAction::Cascade).on_update(ForeignKeyAction::Cascade))
                .to_owned(),
        ).await?;
        
        manager.create_index(Index::create().name("idx_split_record_details_record").table(SplitRecordDetails::Table).col(SplitRecordDetails::SplitRecordSerialNum).to_owned()).await?;
        manager.create_index(Index::create().name("idx_split_record_details_member").table(SplitRecordDetails::Table).col(SplitRecordDetails::MemberSerialNum).to_owned()).await?;
        manager.create_index(Index::create().name("idx_split_record_details_paid").table(SplitRecordDetails::Table).col(SplitRecordDetails::IsPaid).to_owned()).await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(SplitRecordDetails::Table).to_owned()).await
    }
}
