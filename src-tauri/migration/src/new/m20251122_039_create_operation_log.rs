use sea_orm_migration::prelude::*;
use crate::schema::OperationLog;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.create_table(Table::create().table(OperationLog::Table).if_not_exists()
            .col(ColumnDef::new(OperationLog::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(OperationLog::ActorId).string_len(38).null())
            .col(ColumnDef::new(OperationLog::Operation).string().not_null())
            .col(ColumnDef::new(OperationLog::TargetTable).string().null())
            .col(ColumnDef::new(OperationLog::RecordId).string_len(38).null())
            .col(ColumnDef::new(OperationLog::ChangesJson).json().null())
            .col(ColumnDef::new(OperationLog::SnapshotJson).json().null())
            .col(ColumnDef::new(OperationLog::DeviceId).string().null())
            .col(ColumnDef::new(OperationLog::RecordedAt).timestamp_with_time_zone().not_null())
            .to_owned()).await?;
        
        manager.create_index(Index::create().name("idx_operation_log_actor").table(OperationLog::Table).col(OperationLog::ActorId).to_owned()).await?;
        manager.create_index(Index::create().name("idx_operation_log_recorded").table(OperationLog::Table).col(OperationLog::RecordedAt).to_owned()).await?;
        Ok(())
    }
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(OperationLog::Table).to_owned()).await
    }
}
