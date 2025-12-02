use sea_orm_migration::prelude::*;
use crate::schema::Project;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.create_table(Table::create().table(Project::Table).if_not_exists()
            .col(ColumnDef::new(Project::SerialNum).string_len(38).not_null().primary_key())
            .col(ColumnDef::new(Project::Name).string_len(200).not_null())
            .col(ColumnDef::new(Project::Description).text().null())
            .col(ColumnDef::new(Project::Color).string_len(7).null())
            .col(ColumnDef::new(Project::IsArchived).boolean().not_null().default(false))
            .col(ColumnDef::new(Project::CreatedAt).timestamp_with_time_zone().not_null())
            .col(ColumnDef::new(Project::UpdatedAt).timestamp_with_time_zone().null())
            .to_owned()).await?;
        Ok(())
    }
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(Project::Table).to_owned()).await
    }
}
