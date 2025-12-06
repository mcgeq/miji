use sea_orm_migration::prelude::*;

use crate::schema::{Currency, FamilyLedger};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 family_ledger 表（整合所有字段）
        manager
            .create_table(
                Table::create()
                    .table(FamilyLedger::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FamilyLedger::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(FamilyLedger::Name).string())
                    .col(
                        ColumnDef::new(FamilyLedger::Description)
                            .string_len(1000)
                            .not_null()
                            .default(""),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::BaseCurrency)
                            .string_len(3)
                            .not_null(),
                    )
                    // 计数字段（integer类型）
                    .col(
                        ColumnDef::new(FamilyLedger::Members)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Accounts)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Transactions)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Budgets)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::AuditLogs)
                            .string()
                            .not_null()
                            .default("[]"),
                    )
                    // 账本类型和状态
                    .col(
                        ColumnDef::new(FamilyLedger::LedgerType)
                            .string_len(20)
                            .not_null()
                            .default("Family")
                            .check(
                                Expr::col(FamilyLedger::LedgerType)
                                    .is_in(vec!["Personal", "Family", "Project", "Business"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Status)
                            .string_len(20)
                            .not_null()
                            .default("Active")
                            .check(Expr::col(FamilyLedger::Status).is_in(vec![
                                "Active",
                                "Archived",
                                "Suspended",
                            ])),
                    )
                    // 结算相关字段
                    .col(
                        ColumnDef::new(FamilyLedger::SettlementCycle)
                            .string_len(20)
                            .not_null()
                            .default("Monthly")
                            .check(Expr::col(FamilyLedger::SettlementCycle).is_in(vec![
                                "Weekly",
                                "Monthly",
                                "Quarterly",
                                "Yearly",
                                "Manual",
                            ])),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::SettlementDay)
                            .integer()
                            .not_null()
                            .default(1)
                            .check(Expr::col(FamilyLedger::SettlementDay).between(1, 366)),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::AutoSettlement)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(FamilyLedger::DefaultSplitRule).json().null())
                    .col(
                        ColumnDef::new(FamilyLedger::LastSettlementAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::NextSettlementAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    // 财务统计字段
                    .col(
                        ColumnDef::new(FamilyLedger::TotalIncome)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::TotalExpense)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::SharedExpense)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::PersonalExpense)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::PendingSettlement)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.00),
                    )
                    // 时间戳
                    .col(
                        ColumnDef::new(FamilyLedger::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    // 外键约束
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_currency")
                            .from(FamilyLedger::Table, FamilyLedger::BaseCurrency)
                            .to(Currency::Table, Currency::Code)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_family_ledger_status")
                    .table(FamilyLedger::Table)
                    .col(FamilyLedger::Status)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_family_ledger_type")
                    .table(FamilyLedger::Table)
                    .col(FamilyLedger::LedgerType)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_family_ledger_type").to_owned())
            .await?;

        manager
            .drop_index(Index::drop().name("idx_family_ledger_status").to_owned())
            .await?;

        manager
            .drop_table(Table::drop().table(FamilyLedger::Table).to_owned())
            .await?;

        Ok(())
    }
}
