use sea_orm_migration::prelude::*;

use crate::schema::{FamilyMember, Users};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加用户ID关联字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::UserId)
                            .string_len(38)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加头像URL字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::AvatarUrl)
                            .string_len(500)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加颜色标识字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::Color)
                            .string_len(7)
                            .null()
                            .default("#3B82F6"),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加总支付金额统计字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::TotalPaid)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加总欠款金额统计字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::TotalOwed)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加净余额字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::Balance)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加成员状态字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::Status)
                            .string_len(20)
                            .not_null()
                            .default("Active")
                            .check(
                                Expr::col(FamilyMember::Status)
                                    .is_in(vec!["Active", "Inactive", "Suspended"]),
                            ),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加邮箱字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::Email)
                            .string_len(255)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加电话字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_column(
                        ColumnDef::new(FamilyMember::Phone)
                            .string_len(20)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加外键约束
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .add_foreign_key(
                        TableForeignKey::new()
                            .name("fk_family_member_user")
                            .from_col(FamilyMember::UserId)
                            .to_tbl(Users::Table)
                            .to_col(Users::SerialNum)
                            .on_delete(ForeignKeyAction::SetNull)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除外键约束
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .drop_foreign_key(Alias::new("fk_family_member_user"))
                    .to_owned(),
            )
            .await?;

        // 删除添加的字段
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyMember::Table)
                    .drop_column(FamilyMember::UserId)
                    .drop_column(FamilyMember::AvatarUrl)
                    .drop_column(FamilyMember::Color)
                    .drop_column(FamilyMember::TotalPaid)
                    .drop_column(FamilyMember::TotalOwed)
                    .drop_column(FamilyMember::Balance)
                    .drop_column(FamilyMember::Status)
                    .drop_column(FamilyMember::Email)
                    .drop_column(FamilyMember::Phone)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
