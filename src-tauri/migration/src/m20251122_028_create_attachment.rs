use sea_orm_migration::prelude::*;
use crate::schema::{Attachment, Todo};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.create_table(Table::create().table(Attachment::Table).if_not_exists()
            .col(ColumnDef::new(Attachment::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(Attachment::TodoSerialNum).string_len(38).not_null())
            .col(ColumnDef::new(Attachment::FileName).string().not_null())
            .col(ColumnDef::new(Attachment::FilePath).string().not_null())
            .col(ColumnDef::new(Attachment::Size).big_integer().not_null())
            .col(ColumnDef::new(Attachment::MimeType).string().null())
            .col(ColumnDef::new(Attachment::CreatedAt).timestamp_with_time_zone().not_null())
            .foreign_key(ForeignKey::create().from(Attachment::Table, Attachment::TodoSerialNum)
                .to(Todo::Table, Todo::SerialNum).on_delete(ForeignKeyAction::Cascade))
            .to_owned()).await?;
        
        manager.create_index(Index::create().name("idx_attachment_todo").table(Attachment::Table).col(Attachment::TodoSerialNum).to_owned()).await?;
        Ok(())
    }
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(Attachment::Table).to_owned()).await
    }
}
