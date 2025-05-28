use sea_orm_migration::prelude::*;

use crate::period_scheme::{PeriodDailyRecords, PeriodSymptoms};

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
                            .tiny_integer()
                            .not_null()
                            .check(Expr::col(PeriodSymptoms::SymptomType).is_in([0, 1, 2])),
                    )
                    .col(
                        ColumnDef::new(PeriodSymptoms::Intensity)
                            .tiny_integer()
                            .not_null()
                            .check(Expr::col(PeriodSymptoms::Intensity).is_in([0, 1, 2])),
                    )
                    .col(
                        ColumnDef::new(PeriodSymptoms::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodSymptoms::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_period_symptoms_period_daily_records")
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

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(PeriodSymptoms::Table).to_owned())
            .await?;

        Ok(())
    }
}
