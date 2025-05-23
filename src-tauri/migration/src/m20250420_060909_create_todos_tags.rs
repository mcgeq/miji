use sea_orm_migration::prelude::*;

use crate::schema::Tag;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Tag::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Tag::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Tag::Name).string().not_null().unique_key())
                    .col(ColumnDef::new(Tag::Description).string().null())
                    .col(
                        ColumnDef::new(Tag::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Tag::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Tag::Table).to_owned())
            .await?;

        Ok(())
    }
}
