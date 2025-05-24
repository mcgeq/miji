use sea_orm_migration::prelude::*;

use crate::schema::{Project, Todo, TodoProject};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
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
                    .col(ColumnDef::new(TodoProject::Order).integer().null())
                    .col(
                        ColumnDef::new(TodoProject::CreatedAt)
                            .timestamp()
                            .not_null(),
                    )
                    .col(ColumnDef::new(TodoProject::UpdatedAt).timestamp().null())
                    .primary_key(
                        Index::create()
                            .name("pk_todo_project")
                            .col(TodoProject::TodoSerialNum)
                            .col(TodoProject::ProjectSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_todoproject_todo")
                            .from(TodoProject::Table, TodoProject::TodoSerialNum)
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_todoproject_project")
                            .from(TodoProject::Table, TodoProject::ProjectSerialNum)
                            .to(Project::Table, Project::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;
        manager
            .create_index(
                Index::create()
                    .name("idx_todoproject_todo")
                    .table(TodoProject::Table)
                    .col(TodoProject::TodoSerialNum)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todoproject_project")
                    .table(TodoProject::Table)
                    .col(TodoProject::ProjectSerialNum)
                    .to_owned(),
            )
            .await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("idx_todoproject_todo")
                    .table(TodoProject::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_todoproject_project")
                    .table(TodoProject::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(TodoProject::Table).to_owned())
            .await?;

        Ok(())
    }
}
