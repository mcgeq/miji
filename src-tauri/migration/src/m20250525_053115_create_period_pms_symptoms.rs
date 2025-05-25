use sea_orm_migration::prelude::*;

use crate::period_scheme::{Intensity, PeriodPmsRecords, PeriodPmsSymptoms, SymptomsType};

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
                            .custom(SymptomsType::Type)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PeriodPmsSymptoms::Intensity)
                            .custom(Intensity::Type)
                            .not_null(),
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
                            .name("fk_period_pms_symptoms_period_pms_records")
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

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(PeriodPmsSymptoms::Table).to_owned())
            .await?;

        Ok(())
    }
}
