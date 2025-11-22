use sea_orm_migration::prelude::*;

use crate::schema::{FamilyMember, Users};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 family_member 表（整合所有字段）
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
                    // 用户关联和个人信息
                    .col(
                        ColumnDef::new(FamilyMember::UserId)
                            .string_len(38)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::AvatarUrl)
                            .string_len(500)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::Color)
                            .string_len(7)
                            .null()
                            .default("#3B82F6"),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::Email)
                            .string_len(255)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::Phone)
                            .string_len(20)
                            .null(),
                    )
                    // 财务统计字段
                    .col(
                        ColumnDef::new(FamilyMember::TotalPaid)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::TotalOwed)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .col(
                        ColumnDef::new(FamilyMember::Balance)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    // 状态字段
                    .col(
                        ColumnDef::new(FamilyMember::Status)
                            .string_len(20)
                            .not_null()
                            .default("Active")
                            .check(
                                Expr::col(FamilyMember::Status)
                                    .is_in(vec!["Active", "Inactive", "Suspended"]),
                            ),
                    )
                    // 时间戳
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
                    // 外键约束（可选的用户关联）
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_member_user")
                            .from(FamilyMember::Table, FamilyMember::UserId)
                            .to(Users::Table, Users::SerialNum)
                            .on_delete(ForeignKeyAction::SetNull)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建唯一索引（name字段唯一）
        manager
            .create_index(
                Index::create()
                    .name("idx_family_member_name_unique")
                    .table(FamilyMember::Table)
                    .col(FamilyMember::Name)
                    .unique()
                    .to_owned(),
            )
            .await?;

        // 创建其他索引
        manager
            .create_index(
                Index::create()
                    .name("idx_family_member_user")
                    .table(FamilyMember::Table)
                    .col(FamilyMember::UserId)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_family_member_status")
                    .table(FamilyMember::Table)
                    .col(FamilyMember::Status)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_member_status")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_member_user")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_member_name_unique")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(FamilyMember::Table).to_owned())
            .await?;

        Ok(())
    }
}
