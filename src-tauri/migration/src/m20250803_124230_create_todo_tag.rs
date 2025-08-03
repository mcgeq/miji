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
                    .col(ColumnDef::new(TodoTag::Orders).integer())
                    .col(ColumnDef::new(TodoTag::CreatedAt).string().not_null())
                    .col(ColumnDef::new(TodoTag::UpdatedAt).string())
                    .primary_key(
                        Index::create()
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

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_tag_todo")
                    .table(TodoTag::Table)
                    .col(TodoTag::TodoSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_tag_tag")
                    .table(TodoTag::Table)
                    .col(TodoTag::TagSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_todo_tag_todo").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_todo_tag_tag").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(TodoTag::Table).to_owned())
            .await?;

        Ok(())
    }
}
