use sea_orm_migration::prelude::*;

use crate::schema::Users;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 users 表
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
                    .col(
                        ColumnDef::new(Users::LastLoginAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(Users::IsVerified)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(Users::Role)
                            .string()
                            .not_null()
                            .default("User")
                            .check(Expr::col(Users::Role).is_in(vec![
                                "Admin",
                                "User",
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
                    .col(
                        ColumnDef::new(Users::EmailVerifiedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(Users::PhoneVerifiedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(ColumnDef::new(Users::Bio).text())
                    .col(ColumnDef::new(Users::Language).string())
                    .col(ColumnDef::new(Users::Timezone).string())
                    .col(
                        ColumnDef::new(Users::LastActiveAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(Users::DeletedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(Users::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Users::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_users_status")
                    .table(Users::Table)
                    .col(Users::Status)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 注意：默认用户的创建在应用启动时进行，以确保密码被正确哈希

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_users_status").to_owned())
            .await?;

        manager
            .drop_table(Table::drop().table(Users::Table).to_owned())
            .await?;

        Ok(())
    }
}
