use sea_orm_migration::prelude::*;

use crate::schema::Users;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Users::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Users::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Users::Name).string().not_null().unique_key())
                    .col(
                        ColumnDef::new(Users::Email)
                            .string()
                            .not_null()
                            .unique_key(),
                    )
                    .col(ColumnDef::new(Users::Phone).string().unique_key())
                    .col(ColumnDef::new(Users::Password).string().not_null())
                    .col(ColumnDef::new(Users::AvatarUrl).string())
                    .col(ColumnDef::new(Users::LastLoginAt).string())
                    .col(
                        ColumnDef::new(Users::IsVerified)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Users::IsVerified).is_in(vec![0, 1])),
                    )
                    .col(
                        ColumnDef::new(Users::Role)
                            .string()
                            .not_null()
                            .default("Users")
                            .check(Expr::col(Users::Role).is_in(vec![
                                "Admin",
                                "Users",
                                "Moderator",
                                "Editor",
                                "Guest",
                                "Developer",
                                "Owner",
                            ])),
                    )
                    .col(
                        ColumnDef::new(Users::Status)
                            .string()
                            .not_null()
                            .default("Pending")
                            .check(Expr::col(Users::Status).is_in(vec![
                                "Active",
                                "Inactive",
                                "Suspended",
                                "Banned",
                                "Pending",
                                "Deleted",
                            ])),
                    )
                    .col(ColumnDef::new(Users::EmailVerifiedAt).string())
                    .col(ColumnDef::new(Users::PhoneVerifiedAt).string())
                    .col(ColumnDef::new(Users::Bio).text())
                    .col(ColumnDef::new(Users::Language).string())
                    .col(ColumnDef::new(Users::Timezone).string())
                    .col(ColumnDef::new(Users::LastActiveAt).string())
                    .col(ColumnDef::new(Users::DeletedAt).string())
                    .col(ColumnDef::new(Users::CreatedAt).string().not_null())
                    .col(ColumnDef::new(Users::UpdatedAt).string())
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_Users_status")
                    .table(Users::Table)
                    .col(Users::Status)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_Users_status").to_owned())
            .await?;

        manager
            .drop_table(Table::drop().table(Users::Table).to_owned())
            .await?;

        Ok(())
    }
}
