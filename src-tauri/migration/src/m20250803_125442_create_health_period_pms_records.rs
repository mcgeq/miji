use sea_orm_migration::prelude::*;

use crate::schema::{PeriodPmsRecords, PeriodRecords};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(PeriodPmsRecords::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(PeriodPmsRecords::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsRecords::PeriodSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsRecords::StartDate)
                            .string()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsRecords::EndDate)
                            .string()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsRecords::CreatedAt)
                            .string()
                            .not_null(),
                    )
                    .col(ColumnDef::new(PeriodPmsRecords::UpdatedAt).string())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_period_pms_records_period")
                            .from(PeriodPmsRecords::Table, PeriodPmsRecords::PeriodSerialNum)
                            .to(PeriodRecords::Table, PeriodRecords::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_period_pms_records_period")
                    .table(PeriodPmsRecords::Table)
                    .col(PeriodPmsRecords::PeriodSerialNum)
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
                    .name("idx_period_pms_records_period")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(PeriodPmsRecords::Table).to_owned())
            .await?;

        Ok(())
    }
}
