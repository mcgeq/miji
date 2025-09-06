use sea_orm_migration::prelude::*;

use crate::schema::FamilyMember;

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
                    .col(
                        ColumnDef::new(FamilyMember::Name)
                            .string_len(200)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::Role)
                            .string()
                            .not_null()
                            .default("Member")
                            .check(
                                Expr::col(FamilyMember::Role)
                                    .is_in(vec!["Admin", "Member", "Owner", "Viewer"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::IsPrimary)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::Permissions)
                            .string_len(500)
                            .not_null(),
                    )
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
