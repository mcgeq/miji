use sea_orm_migration::prelude::*;
use crate::schema::{PeriodDailyRecords, PeriodPmsRecords, PeriodPmsSymptoms, PeriodRecords, PeriodSettings, PeriodSymptoms};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // PeriodRecords
        manager.create_table(Table::create().table(PeriodRecords::Table).if_not_exists()
            .col(ColumnDef::new(PeriodRecords::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(PeriodRecords::StartDate).date().not_null())
            .col(ColumnDef::new(PeriodRecords::EndDate).date().null())
            .col(ColumnDef::new(PeriodRecords::Notes).text().null())
            .col(ColumnDef::new(PeriodRecords::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(PeriodRecords::UpdatedAt).timestamp_with_time_zone().null())
            .to_owned()).await?;
        
        // PeriodSettings
        manager.create_table(Table::create().table(PeriodSettings::Table).if_not_exists()
            .col(ColumnDef::new(PeriodSettings::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(PeriodSettings::AverageCycleLength).integer().not_null().default(28)
                .check(Expr::cust("average_cycle_length > 0")))
            .col(ColumnDef::new(PeriodSettings::AveragePeriodLength).integer().not_null().default(5)
                .check(Expr::cust("average_period_length > 0")))
            .col(ColumnDef::new(PeriodSettings::PeriodReminder).boolean().not_null().default(false))
            .col(ColumnDef::new(PeriodSettings::OvulationReminder).boolean().not_null().default(false))
            .col(ColumnDef::new(PeriodSettings::PmsReminder).boolean().not_null().default(false))
            .col(ColumnDef::new(PeriodSettings::ReminderDays).integer().not_null().default(3)
                .check(Expr::cust("reminder_days >= 0")))
            .col(ColumnDef::new(PeriodSettings::DataSync).boolean().not_null().default(true))
            .col(ColumnDef::new(PeriodSettings::Analytics).boolean().not_null().default(false))
            .col(ColumnDef::new(PeriodSettings::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(PeriodSettings::UpdatedAt).timestamp_with_time_zone().null())
            .to_owned()).await?;
        
        // PeriodDailyRecords
        manager.create_table(Table::create().table(PeriodDailyRecords::Table).if_not_exists()
            .col(ColumnDef::new(PeriodDailyRecords::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(PeriodDailyRecords::PeriodSerialNum).string_len(38).not_null())
            .col(ColumnDef::new(PeriodDailyRecords::Date).date().not_null())
            .col(ColumnDef::new(PeriodDailyRecords::FlowLevel).string().null())
            .col(ColumnDef::new(PeriodDailyRecords::ExerciseIntensity).string().null())
            .col(ColumnDef::new(PeriodDailyRecords::SexualActivity).boolean().null())
            .col(ColumnDef::new(PeriodDailyRecords::ContraceptionMethod).string().null())
            .col(ColumnDef::new(PeriodDailyRecords::Diet).text().null())
            .col(ColumnDef::new(PeriodDailyRecords::Mood).string().null())
            .col(ColumnDef::new(PeriodDailyRecords::WaterIntake).integer().null())
            .col(ColumnDef::new(PeriodDailyRecords::SleepHours).integer().null())
            .col(ColumnDef::new(PeriodDailyRecords::Notes).text().null())
            .col(ColumnDef::new(PeriodDailyRecords::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(PeriodDailyRecords::UpdatedAt).timestamp_with_time_zone().null())
            .foreign_key(ForeignKey::create().from(PeriodDailyRecords::Table, PeriodDailyRecords::PeriodSerialNum)
                .to(PeriodRecords::Table, PeriodRecords::SerialNum).on_delete(ForeignKeyAction::Cascade))
            .to_owned()).await?;
        
        // PeriodSymptoms
        manager.create_table(Table::create().table(PeriodSymptoms::Table).if_not_exists()
            .col(ColumnDef::new(PeriodSymptoms::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(PeriodSymptoms::PeriodDailyRecordsSerialNum).string_len(38).not_null())
            .col(ColumnDef::new(PeriodSymptoms::SymptomType).string().not_null())
            .col(ColumnDef::new(PeriodSymptoms::Intensity).string().null())
            .col(ColumnDef::new(PeriodSymptoms::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(PeriodSymptoms::UpdatedAt).timestamp_with_time_zone().null())
            .foreign_key(ForeignKey::create().from(PeriodSymptoms::Table, PeriodSymptoms::PeriodDailyRecordsSerialNum)
                .to(PeriodDailyRecords::Table, PeriodDailyRecords::SerialNum).on_delete(ForeignKeyAction::Cascade))
            .to_owned()).await?;
        
        // PeriodPmsRecords
        manager.create_table(Table::create().table(PeriodPmsRecords::Table).if_not_exists()
            .col(ColumnDef::new(PeriodPmsRecords::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(PeriodPmsRecords::PeriodSerialNum).string_len(38).not_null())
            .col(ColumnDef::new(PeriodPmsRecords::StartDate).date().not_null())
            .col(ColumnDef::new(PeriodPmsRecords::EndDate).date().null())
            .col(ColumnDef::new(PeriodPmsRecords::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(PeriodPmsRecords::UpdatedAt).timestamp_with_time_zone().null())
            .foreign_key(ForeignKey::create().from(PeriodPmsRecords::Table, PeriodPmsRecords::PeriodSerialNum)
                .to(PeriodRecords::Table, PeriodRecords::SerialNum).on_delete(ForeignKeyAction::Cascade))
            .to_owned()).await?;
        
        // PeriodPmsSymptoms
        manager.create_table(Table::create().table(PeriodPmsSymptoms::Table).if_not_exists()
            .col(ColumnDef::new(PeriodPmsSymptoms::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(PeriodPmsSymptoms::PeriodPmsRecordsSerialNum).string_len(38).not_null())
            .col(ColumnDef::new(PeriodPmsSymptoms::SymptomType).string().not_null())
            .col(ColumnDef::new(PeriodPmsSymptoms::Intensity).string().null())
            .col(ColumnDef::new(PeriodPmsSymptoms::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(PeriodPmsSymptoms::UpdatedAt).timestamp_with_time_zone().null())
            .foreign_key(ForeignKey::create().from(PeriodPmsSymptoms::Table, PeriodPmsSymptoms::PeriodPmsRecordsSerialNum)
                .to(PeriodPmsRecords::Table, PeriodPmsRecords::SerialNum).on_delete(ForeignKeyAction::Cascade))
            .to_owned()).await?;
        
        Ok(())
    }
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(PeriodPmsSymptoms::Table).to_owned()).await?;
        manager.drop_table(Table::drop().table(PeriodPmsRecords::Table).to_owned()).await?;
        manager.drop_table(Table::drop().table(PeriodSymptoms::Table).to_owned()).await?;
        manager.drop_table(Table::drop().table(PeriodDailyRecords::Table).to_owned()).await?;
        manager.drop_table(Table::drop().table(PeriodSettings::Table).to_owned()).await?;
        manager.drop_table(Table::drop().table(PeriodRecords::Table).to_owned()).await?;
        Ok(())
    }
}
