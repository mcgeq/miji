use sea_orm_migration::prelude::*;

use crate::schema::{PeriodDailyRecords, PeriodSymptoms};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(PeriodSymptoms::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(PeriodSymptoms::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(PeriodSymptoms::PeriodDailyRecordsSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodSymptoms::SymptomType)
                            .integer()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodSymptoms::Intensity)
                            .integer()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodSymptoms::CreatedAt)
                            .string()
                            .not_null(),
                    )
                    .col(ColumnDef::new(PeriodSymptoms::UpdatedAt).string())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_period_symptoms_daily_records")
                            .from(
                                PeriodSymptoms::Table,
                                PeriodSymptoms::PeriodDailyRecordsSerialNum,
                            )
                            .to(PeriodDailyRecords::Table, PeriodDailyRecords::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_period_symptoms_daily_record")
                    .table(PeriodSymptoms::Table)
                    .col(PeriodSymptoms::PeriodDailyRecordsSerialNum)
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
                    .name("idx_period_symptoms_daily_record")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(PeriodSymptoms::Table).to_owned())
            .await?;

        Ok(())
    }
}
