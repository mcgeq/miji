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
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(name) <= 100")),
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
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(FamilyMember::IsPrimary).is_in(vec![0, 1])),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::Permissions)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(permissions) <= 500")),
                    )
                    .col(ColumnDef::new(FamilyMember::CreatedAt).string().not_null())
                    .col(ColumnDef::new(FamilyMember::UpdatedAt).string())
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
