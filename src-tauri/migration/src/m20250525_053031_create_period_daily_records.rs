use sea_orm_migration::prelude::*;

use crate::period_scheme::{ExerciseIntensity, FlowLevel, PeriodDailyRecords, PeriodRecords};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(PeriodDailyRecords::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(PeriodDailyRecords::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::PeriodSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(ColumnDef::new(PeriodDailyRecords::Date).date().not_null())
                    .col(
                        ColumnDef::new(PeriodDailyRecords::FlowLevel)
                            .custom(FlowLevel::Type)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::SexualActivity)
                            .boolean()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::ExerciseIntensity)
                            .custom(ExerciseIntensity::Type)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::Diet)
                            .string_len(255)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_period_daily_records_period")
                            .from(
                                PeriodDailyRecords::Table,
                                PeriodDailyRecords::PeriodSerialNum,
                            )
                            .to(PeriodRecords::Table, PeriodRecords::SerialNum)
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
            .drop_table(Table::drop().table(PeriodDailyRecords::Table).to_owned())
            .await?;

        Ok(())
    }
}
