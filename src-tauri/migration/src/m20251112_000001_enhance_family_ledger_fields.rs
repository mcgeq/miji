use sea_orm_migration::prelude::*;

use crate::schema::FamilyLedger;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 检查并添加账本类型字段
        if !manager.has_column("family_ledger", "ledger_type").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::LedgerType)
                                .string_len(20)
                                .not_null()
                                .default("Family")
                                .check(
                                    Expr::col(FamilyLedger::LedgerType)
                                        .is_in(vec!["Personal", "Family", "Project", "Business"]),
                                ),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 检查并添加结算周期字段
        if !manager.has_column("family_ledger", "settlement_cycle").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::SettlementCycle)
                                .string_len(20)
                                .not_null()
                                .default("Monthly")
                                .check(
                                    Expr::col(FamilyLedger::SettlementCycle)
                                        .is_in(vec!["Weekly", "Monthly", "Quarterly", "Yearly", "Manual"]),
                                ),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 检查并添加自动结算字段
        if !manager.has_column("family_ledger", "auto_settlement").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::AutoSettlement)
                                .boolean()
                                .not_null()
                                .default(false),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 检查并添加默认分摊规则字段
        if !manager.has_column("family_ledger", "default_split_rule").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::DefaultSplitRule)
                                .json()
                                .null(),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 检查并添加最后结算时间字段
        if !manager.has_column("family_ledger", "last_settlement_at").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::LastSettlementAt)
                                .timestamp_with_time_zone()
                                .null(),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 检查并添加下次结算时间字段
        if !manager.has_column("family_ledger", "next_settlement_at").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::NextSettlementAt)
                                .timestamp_with_time_zone()
                                .null(),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 检查并添加账本状态字段
        if !manager.has_column("family_ledger", "status").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::Status)
                                .string_len(20)
                                .not_null()
                                .default("Active")
                                .check(
                                    Expr::col(FamilyLedger::Status)
                                        .is_in(vec!["Active", "Archived", "Suspended"]),
                                ),
                        )
                        .to_owned(),
                )
                .await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyLedger::Table)
                    .drop_column(FamilyLedger::LedgerType)
                    .drop_column(FamilyLedger::SettlementCycle)
                    .drop_column(FamilyLedger::AutoSettlement)
                    .drop_column(FamilyLedger::DefaultSplitRule)
                    .drop_column(FamilyLedger::LastSettlementAt)
                    .drop_column(FamilyLedger::NextSettlementAt)
                    .drop_column(FamilyLedger::Status)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
