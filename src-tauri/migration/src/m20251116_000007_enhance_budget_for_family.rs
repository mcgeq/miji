use sea_orm_migration::prelude::*;

use crate::schema::{Budget, BudgetAllocations};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 1. 扩展 Budget 表，添加家庭账本关联字段
        // SQLite 不支持一次添加多列，需要分开执行
        // 使用 has_column 检查避免重复添加
        if !manager.has_column("budget", "family_ledger_serial_num").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(Budget::Table)
                        .add_column(
                            ColumnDef::new(Budget::FamilyLedgerSerialNum)
                                .string_len(38)
                                .null(),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 2. 添加创建者字段
        if !manager.has_column("budget", "created_by").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(Budget::Table)
                        .add_column(
                            ColumnDef::new(Budget::CreatedBy)
                                .string()
                                .null(),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 2. 创建 budget_allocations 表（支持家庭预算的成员/分类分配）
        manager
            .create_table(
                Table::create()
                    .table(BudgetAllocations::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(BudgetAllocations::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::BudgetSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::CategorySerialNum)
                            .string_len(38)
                            .null()
                            .comment("分类序列号，null表示所有分类"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::MemberSerialNum)
                            .string()
                            .null()
                            .comment("成员序列号，null表示所有成员"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::AllocatedAmount)
                            .decimal_len(15, 2)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::UsedAmount)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::RemainingAmount)
                            .decimal_len(15, 2)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::Percentage)
                            .decimal_len(5, 2)
                            .null()
                            .comment("占总预算的百分比"),
                    )
                    // 分配规则
                    .col(
                        ColumnDef::new(BudgetAllocations::AllocationType)
                            .string()
                            .not_null()
                            .default("FIXED_AMOUNT")
                            .comment("分配类型: FIXED_AMOUNT, PERCENTAGE, SHARED, DYNAMIC"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::RuleConfig)
                            .json_binary()
                            .null()
                            .comment("规则配置（复杂规则）"),
                    )
                    // 超支控制
                    .col(
                        ColumnDef::new(BudgetAllocations::AllowOverspend)
                            .boolean()
                            .not_null()
                            .default(false)
                            .comment("是否允许超支"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::OverspendLimitType)
                            .string()
                            .null()
                            .comment("超支限额类型: NONE, PERCENTAGE, FIXED_AMOUNT"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::OverspendLimitValue)
                            .decimal_len(10, 2)
                            .null()
                            .comment("超支限额值"),
                    )
                    // 预警设置
                    .col(
                        ColumnDef::new(BudgetAllocations::AlertEnabled)
                            .boolean()
                            .not_null()
                            .default(true)
                            .comment("启用预警"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::AlertThreshold)
                            .integer()
                            .not_null()
                            .default(80)
                            .comment("预警阈值百分比(1-100)"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::AlertConfig)
                            .json_binary()
                            .null()
                            .comment("预警配置（多级预警等）"),
                    )
                    // 管理字段
                    .col(
                        ColumnDef::new(BudgetAllocations::Priority)
                            .integer()
                            .not_null()
                            .default(3)
                            .comment("优先级(1-5)，5最高"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::IsMandatory)
                            .boolean()
                            .not_null()
                            .default(false)
                            .comment("是否强制保障（不可削减）"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::Status)
                            .string()
                            .not_null()
                            .default("ACTIVE")
                            .comment("状态: ACTIVE, PAUSED, COMPLETED"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::Notes)
                            .text()
                            .null()
                            .comment("备注说明"),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BudgetAllocations::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    // 在创建表时直接定义外键（SQLite 要求）
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_budget_allocations_budget")
                            .from(BudgetAllocations::Table, BudgetAllocations::BudgetSerialNum)
                            .to(Budget::Table, Budget::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade)
                    )
                    .to_owned(),
            )
            .await?;

        // 3. 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_budget_family_ledger")
                    .table(Budget::Table)
                    .col(Budget::FamilyLedgerSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_budget_allocations_budget")
                    .table(BudgetAllocations::Table)
                    .col(BudgetAllocations::BudgetSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_budget_allocations_category")
                    .table(BudgetAllocations::Table)
                    .col(BudgetAllocations::CategorySerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_budget_allocations_member")
                    .table(BudgetAllocations::Table)
                    .col(BudgetAllocations::MemberSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除索引（外键会随表删除而自动删除）
        manager
            .drop_index(
                Index::drop()
                    .name("idx_budget_allocations_member")
                    .table(BudgetAllocations::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_budget_allocations_category")
                    .table(BudgetAllocations::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_budget_allocations_budget")
                    .table(BudgetAllocations::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_budget_family_ledger")
                    .table(Budget::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await?;

        // 删除 budget_allocations 表
        manager
            .drop_table(Table::drop().table(BudgetAllocations::Table).to_owned())
            .await?;

        // 删除 Budget 表的新增字段（SQLite需要分开删除）
        if manager.has_column("budget", "created_by").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(Budget::Table)
                        .drop_column(Budget::CreatedBy)
                        .to_owned(),
                )
                .await?;
        }

        if manager.has_column("budget", "family_ledger_serial_num").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(Budget::Table)
                        .drop_column(Budget::FamilyLedgerSerialNum)
                        .to_owned(),
                )
                .await?;
        }

        Ok(())
    }
}
