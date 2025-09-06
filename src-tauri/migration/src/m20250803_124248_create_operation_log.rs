use sea_orm_migration::prelude::*;

use crate::schema::OperationLog;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(OperationLog::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(OperationLog::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(OperationLog::RecordedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(OperationLog::Operation)
                            .string()
                            .not_null()
                            .check(Expr::col(OperationLog::Operation).is_in(vec![
                                "INSERT",
                                "UPDATE",
                                "DELETE",
                                "SOFT_DELETE",
                                "RESTORE",
                            ])),
                    )
                    .col(
                        ColumnDef::new(OperationLog::TargetTable)
                            .string()
                            .not_null(),
                    )
                    .col(ColumnDef::new(OperationLog::RecordId).string().not_null())
                    .col(
                        ColumnDef::new(OperationLog::ActorId)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(actor_id) > 0")),
                    )
                    .col(ColumnDef::new(OperationLog::ChangesJson).json_binary())
                    .col(ColumnDef::new(OperationLog::SnapshotJson).json_binary())
                    .col(
                        ColumnDef::new(OperationLog::DeviceId)
                            .string()
                            .check(Expr::cust("LENGTH(device_id) <= 100")),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_oplog_main")
                    .table(OperationLog::Table)
                    .col(OperationLog::TargetTable)
                    .col(OperationLog::RecordedAt)
                    .col(OperationLog::Operation)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_oplog_target")
                    .table(OperationLog::Table)
                    .col(OperationLog::TargetTable)
                    .col(OperationLog::RecordId)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_oplog_actor")
                    .table(OperationLog::Table)
                    .col(OperationLog::ActorId)
                    .col(OperationLog::RecordedAt)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_oplog_main").to_owned())
            .await?;

        manager
            .drop_index(Index::drop().name("idx_oplog_target").to_owned())
            .await?;

        manager
            .drop_index(Index::drop().name("idx_oplog_actor").to_owned())
            .await?;

        manager
            .drop_table(Table::drop().table(OperationLog::Table).to_owned())
            .await?;

        Ok(())
    }
}
