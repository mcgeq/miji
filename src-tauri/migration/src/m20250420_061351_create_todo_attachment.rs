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
                    .col(ColumnDef::new(Attachment::FilePath).string().null())
                    .col(ColumnDef::new(Attachment::Url).string().null())
                    .col(ColumnDef::new(Attachment::FileName).string().null())
                    .col(ColumnDef::new(Attachment::MimeType).string().null())
                    .col(ColumnDef::new(Attachment::Size).integer().null())
                    .col(
                        ColumnDef::new(Attachment::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
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

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Attachment::Table).to_owned())
            .await?;

        Ok(())
    }
}
