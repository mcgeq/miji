use sea_orm_migration::prelude::*;

use crate::schema::{TaskDependency, Todo};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(TaskDependency::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(TaskDependency::TaskSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(TaskDependency::DependsOnTaskSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(TaskDependency::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(TaskDependency::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .primary_key(
                        Index::create()
                            .col(TaskDependency::TaskSerialNum)
                            .col(TaskDependency::DependsOnTaskSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_task_dependency_task")
                            .from(TaskDependency::Table, TaskDependency::TaskSerialNum)
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_task_dependency_depends")
                            .from(
                                TaskDependency::Table,
                                TaskDependency::DependsOnTaskSerialNum,
                            )
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_task_dependency_task")
                    .table(TaskDependency::Table)
                    .col(TaskDependency::TaskSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_task_dependency_depends")
                    .table(TaskDependency::Table)
                    .col(TaskDependency::DependsOnTaskSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_task_dependency_task").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_task_dependency_depends").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(TaskDependency::Table).to_owned())
            .await?;

        Ok(())
    }
}
