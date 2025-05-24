use sea_orm_migration::prelude::extension::postgres::Type;
use sea_orm_migration::prelude::*;

use crate::schema::{User, UserRole, UserStatus};
#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建用户角色 ENUM 类型
        manager
            .create_type(
                Type::create()
                    .as_enum(UserRole::Type)
                    .values(vec![Alias::new("admin"), Alias::new("user")])
                    .to_owned(),
            )
            .await?;

        // 创建用户状态 ENUM 类型
        manager
            .create_type(
                Type::create()
                    .as_enum(UserStatus::Type)
                    .values(vec![Alias::new("active"), Alias::new("inactive")])
                    .to_owned(),
            )
            .await?;

        // 创建 users 表
        manager
            .create_table(
                Table::create()
                    .table(User::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(User::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(User::Name).string().not_null().unique_key())
                    .col(ColumnDef::new(User::Email).string().not_null().unique_key())
                    .col(ColumnDef::new(User::Phone).string().null().unique_key())
                    .col(ColumnDef::new(User::PasswordHash).string().not_null())
                    .col(ColumnDef::new(User::AvatarUrl).string().null())
                    .col(ColumnDef::new(User::LastLoginAt).timestamp().null())
                    .col(
                        ColumnDef::new(User::IsVerified)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(User::Role)
                            .custom(UserRole::Type)
                            .not_null()
                            .default("user"),
                    )
                    .col(
                        ColumnDef::new(User::Status)
                            .custom(UserStatus::Type)
                            .not_null()
                            .default("active"),
                    )
                    .col(
                        ColumnDef::new(User::EmailVerifiedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(User::PhoneVerifiedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(ColumnDef::new(User::Bio).string().null())
                    .col(ColumnDef::new(User::Language).string().null())
                    .col(ColumnDef::new(User::Timezone).string().null())
                    .col(
                        ColumnDef::new(User::LastActiveAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(ColumnDef::new(User::DeletedAt).timestamp().null())
                    .col(ColumnDef::new(User::CreatedAt).timestamp().not_null())
                    .col(ColumnDef::new(User::UpdatedAt).timestamp().null())
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_user_email")
                    .table(User::Table)
                    .col(User::Email)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_user_status")
                    .table(User::Table)
                    .col(User::Status)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除索引
        manager
            .drop_index(
                Index::drop()
                    .name("idx_user_status")
                    .table(User::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_user_email")
                    .table(User::Table)
                    .to_owned(),
            )
            .await?;

        // 删除 users 表
        manager
            .drop_table(Table::drop().table(User::Table).to_owned())
            .await?;

        // 删除 ENUM 类型
        manager
            .drop_type(Type::drop().name(UserStatus::Type).to_owned())
            .await?;

        manager
            .drop_type(Type::drop().name(UserRole::Type).to_owned())
            .await?;

        Ok(())
    }
}
