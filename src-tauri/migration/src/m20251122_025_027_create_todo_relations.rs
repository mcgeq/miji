use crate::schema::{Project, Tag, TaskDependency, Todo, TodoProject, TodoTag};
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // TodoProject关联表
        manager
            .create_table(
                Table::create()
                    .table(TodoProject::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(TodoProject::TodoSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(TodoProject::ProjectSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(TodoProject::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .primary_key(
                        Index::create()
                            .col(TodoProject::TodoSerialNum)
                            .col(TodoProject::ProjectSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(TodoProject::Table, TodoProject::TodoSerialNum)
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(TodoProject::Table, TodoProject::ProjectSerialNum)
                            .to(Project::Table, Project::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // TodoTag关联表
        manager
            .create_table(
                Table::create()
                    .table(TodoTag::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(TodoTag::TodoSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(TodoTag::TagSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(TodoTag::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .primary_key(
                        Index::create()
                            .col(TodoTag::TodoSerialNum)
                            .col(TodoTag::TagSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(TodoTag::Table, TodoTag::TodoSerialNum)
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(TodoTag::Table, TodoTag::TagSerialNum)
                            .to(Tag::Table, Tag::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // TaskDependency依赖表
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
                    .primary_key(
                        Index::create()
                            .col(TaskDependency::TaskSerialNum)
                            .col(TaskDependency::DependsOnTaskSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(TaskDependency::Table, TaskDependency::TaskSerialNum)
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(
                                TaskDependency::Table,
                                TaskDependency::DependsOnTaskSerialNum,
                            )
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade),
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
        manager
            .drop_table(Table::drop().table(TodoTag::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(TodoProject::Table).to_owned())
            .await?;
        Ok(())
    }
}
