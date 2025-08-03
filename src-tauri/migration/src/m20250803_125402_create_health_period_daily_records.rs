use sea_orm_migration::prelude::*;

use crate::schema::{PeriodDailyRecords, PeriodRecords};

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
                    .col(ColumnDef::new(PeriodDailyRecords::Date).string().not_null())
                    .col(
                        ColumnDef::new(PeriodDailyRecords::FlowLevel)
                            .string()
                            .check(
                                Expr::col(PeriodDailyRecords::FlowLevel)
                                    .is_in(vec!["Light", "Medium", "Heavy"]),
                            ),
                    )
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
                            .integer()
                            .not_null()
                            .check(Expr::col(PeriodDailyRecords::SexualActivity).is_in(vec![0, 1])),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::ContraceptionMethod)
                            .string()
                            .default("None")
                            .check(
                                Expr::col(PeriodDailyRecords::ContraceptionMethod)
                                    .is_in(vec!["None", "Condom", "Pill", "Iud", "Other"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(PeriodDailyRecords::Diet)
                            .text()
                            .not_null()
                            .check(Expr::cust("LENGTH(diet) <= 1000")),
                    )
                    .col(ColumnDef::new(PeriodDailyRecords::Mood).string().check(
                        Expr::col(PeriodDailyRecords::Mood).is_in(vec![
                            "Happy",
                            "Sad",
                            "Angry",
                            "Anxious",
                            "Calm",
                            "Irritable",
                        ]),
                    ))
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
                            .string()
                            .not_null(),
                    )
                    .col(ColumnDef::new(PeriodDailyRecords::UpdatedAt).string())
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
