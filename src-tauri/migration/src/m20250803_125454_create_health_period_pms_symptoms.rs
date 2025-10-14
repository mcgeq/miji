use sea_orm_migration::prelude::*;

use crate::schema::{PeriodPmsRecords, PeriodPmsSymptoms};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(PeriodPmsSymptoms::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(PeriodPmsSymptoms::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsSymptoms::PeriodPmsRecordsSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsSymptoms::SymptomType)
                            .string()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsSymptoms::Intensity)
                            .string()
                            .not_null()
                            .check(
                                Expr::col(PeriodPmsSymptoms::Intensity)
                                    .is_in(vec!["Light", "Medium", "Heavy"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsSymptoms::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsSymptoms::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_period_pms_symptoms_pms_records")
                            .from(
                                PeriodPmsSymptoms::Table,
                                PeriodPmsSymptoms::PeriodPmsRecordsSerialNum,
                            )
                            .to(PeriodPmsRecords::Table, PeriodPmsRecords::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_period_pms_symptoms_pms_record")
                    .table(PeriodPmsSymptoms::Table)
                    .col(PeriodPmsSymptoms::PeriodPmsRecordsSerialNum)
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
                    .name("idx_period_pms_symptoms_pms_record")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(PeriodPmsSymptoms::Table).to_owned())
            .await?;

        Ok(())
    }
}
