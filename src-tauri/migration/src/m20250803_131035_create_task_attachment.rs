use sea_orm_migration::prelude::*;

use crate::schema::{Attachment, Todo};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Attachment::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Attachment::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(Attachment::TodoSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(ColumnDef::new(Attachment::FilePath).string())
                    .col(ColumnDef::new(Attachment::Url).string())
                    .col(ColumnDef::new(Attachment::FileName).string())
                    .col(ColumnDef::new(Attachment::MimeType).string())
                    .col(ColumnDef::new(Attachment::Size).integer())
                    .col(
                        ColumnDef::new(Attachment::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Attachment::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_attachment_todo")
                            .from(Attachment::Table, Attachment::TodoSerialNum)
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
                    .name("idx_attachment_todo")
                    .table(Attachment::Table)
                    .col(Attachment::TodoSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_attachment_todo").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Attachment::Table).to_owned())
            .await?;

        Ok(())
    }
}
