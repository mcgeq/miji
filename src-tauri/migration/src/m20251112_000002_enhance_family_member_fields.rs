use sea_orm_migration::prelude::*;

use crate::schema::FamilyMember;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 检查并添加用户ID关联字段
        if !manager.has_column("family_member", "user_id").await? {
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
        }

        // 检查并添加头像URL字段
        if !manager.has_column("family_member", "avatar_url").await? {
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
        }

        // 检查并添加颜色标识字段
        if !manager.has_column("family_member", "color").await? {
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
        }

        // 检查并添加总支付金额统计字段
        if !manager.has_column("family_member", "total_paid").await? {
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
        }

        // 检查并添加总欠款金额统计字段
        if !manager.has_column("family_member", "total_owed").await? {
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
        }

        // 检查并添加净余额字段
        if !manager.has_column("family_member", "balance").await? {
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
        }

        // 检查并添加成员状态字段
        if !manager.has_column("family_member", "status").await? {
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
        }

        // 检查并添加邮箱字段
        if !manager.has_column("family_member", "email").await? {
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
        }

        // 检查并添加电话字段
        if !manager.has_column("family_member", "phone").await? {
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
        }

        // SQLite不支持通过ALTER TABLE添加外键约束
        // 外键约束将在应用层处理，或者在创建新表时定义

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // SQLite不支持删除外键约束，跳过此步骤
        
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
