use sea_orm_migration::prelude::*;

use crate::schema::{Tag, Todo, TodoTag};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
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
                    .col(ColumnDef::new(TodoTag::Order).integer().null())
                    .col(ColumnDef::new(TodoTag::CreatedAt).timestamp().not_null())
                    .col(ColumnDef::new(TodoTag::UpdatedAt).timestamp().null())
                    .primary_key(
                        Index::create()
                            .name("pk_todo_tag")
                            .col(TodoTag::TodoSerialNum)
                            .col(TodoTag::TagSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_todo_tag_todo")
                            .from(TodoTag::Table, TodoTag::TodoSerialNum)
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_todo_tag_tag")
                            .from(TodoTag::Table, TodoTag::TagSerialNum)
                            .to(Tag::Table, Tag::SerialNum)
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
            .drop_table(Table::drop().table(TodoTag::Table).to_owned())
            .await?;

        Ok(())
    }
}
