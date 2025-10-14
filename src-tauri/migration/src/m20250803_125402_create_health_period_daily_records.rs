use sea_orm_migration::prelude::*;

use crate::schema::PeriodDailyRecords;

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
                    .col(
                        ColumnDef::new(PeriodDailyRecords::Date)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(ColumnDef::new(PeriodDailyRecords::FlowLevel).string())
                    .col(
                        ColumnDef::new(PeriodDailyRecords::ExerciseIntensity)
                            .string()
                            .not_null()
                            .default("None")
                            .check(
                                Expr::col(PeriodDailyRecords::ExerciseIntensity)
                                    .is_in(vec!["None", "Light", "Medium", "Heavy"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::SexualActivity)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::ContraceptionMethod)
                            .string()
                            .default("None"),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::Diet)
                            .string_len(1000)
                            .not_null(),
                    )
                    .col(ColumnDef::new(PeriodDailyRecords::Mood).string())
                    .col(
                        ColumnDef::new(PeriodDailyRecords::WaterIntake)
                            .integer()
                            .check(Expr::cust("water_intake <= 5000")),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::SleepHours)
                            .integer()
                            .check(Expr::cust("sleep_hours >= 0 AND sleep_hours <= 24")),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::Notes)
                            .text()
                            .check(Expr::cust("LENGTH(notes) <= 5000")),
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
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_period_daily_records_period")
                    .table(PeriodDailyRecords::Table)
                    .col(PeriodDailyRecords::PeriodSerialNum)
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
                    .name("idx_period_daily_records_period")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(PeriodDailyRecords::Table).to_owned())
            .await?;

        Ok(())
    }
}
