use sea_orm_migration::prelude::*;

use crate::schema::PeriodSettings;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(PeriodSettings::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(PeriodSettings::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::AverageCycleLength)
                            .integer()
                            .not_null()
                            .check(Expr::cust("average_cycle_length > 0")),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::AveragePeriodLength)
                            .integer()
                            .not_null()
                            .check(Expr::cust("average_period_length > 0")),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::PeriodReminder)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::OvulationReminder)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::PmsReminder)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::ReminderDays)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::cust("reminder_days >= 0")),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::DataSync)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::Analytics)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodSettings::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(PeriodSettings::Table).to_owned())
            .await?;

        Ok(())
    }
}
