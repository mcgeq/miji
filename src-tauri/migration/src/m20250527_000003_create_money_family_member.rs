use sea_orm_migration::prelude::*;

use crate::money_scheme::FamilyMember;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(FamilyMember::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FamilyMember::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(FamilyMember::Name).string().not_null())
                    .col(ColumnDef::new(FamilyMember::Role).string().not_null())
                    .col(ColumnDef::new(FamilyMember::IsPrimary).boolean().not_null())
                    .col(ColumnDef::new(FamilyMember::Permissions).json().not_null())
                    .col(
                        ColumnDef::new(FamilyMember::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::UpdatedAt)
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
            .drop_table(Table::drop().table(FamilyMember::Table).to_owned())
            .await?;
        Ok(())
    }
}
