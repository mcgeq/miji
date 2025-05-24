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
                    .primary_key(
                        Index::create()
                            .name("pk_task_dependency")
                            .col(TaskDependency::TaskSerialNum)
                            .col(TaskDependency::DependsOnTaskSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_task_dep_task")
                            .from(TaskDependency::Table, TaskDependency::TaskSerialNum)
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_task_dep_depends_on")
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

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(TaskDependency::Table).to_owned())
            .await?;

        Ok(())
    }
}
