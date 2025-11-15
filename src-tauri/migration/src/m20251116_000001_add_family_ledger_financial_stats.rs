use sea_orm_migration::prelude::*;

use crate::schema::FamilyLedger;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加总收入字段
        if !manager.has_column("family_ledger", "total_income").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::TotalIncome)
                                .decimal_len(15, 2)
                                .not_null()
                                .default(0.00),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 添加总支出字段
        if !manager.has_column("family_ledger", "total_expense").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::TotalExpense)
                                .decimal_len(15, 2)
                                .not_null()
                                .default(0.00),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 添加共同支出字段
        if !manager.has_column("family_ledger", "shared_expense").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::SharedExpense)
                                .decimal_len(15, 2)
                                .not_null()
                                .default(0.00),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 添加个人支出字段
        if !manager.has_column("family_ledger", "personal_expense").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::PersonalExpense)
                                .decimal_len(15, 2)
                                .not_null()
                                .default(0.00),
                        )
                        .to_owned(),
                )
                .await?;
        }

        // 添加待结算金额字段
        if !manager.has_column("family_ledger", "pending_settlement").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::PendingSettlement)
                                .decimal_len(15, 2)
                                .not_null()
                                .default(0.00),
                        )
                        .to_owned(),
                )
                .await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除待结算金额字段
        if manager.has_column("family_ledger", "pending_settlement").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .drop_column(FamilyLedger::PendingSettlement)
                        .to_owned(),
                )
                .await?;
        }

        // 删除个人支出字段
        if manager.has_column("family_ledger", "personal_expense").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .drop_column(FamilyLedger::PersonalExpense)
                        .to_owned(),
                )
                .await?;
        }

        // 删除共同支出字段
        if manager.has_column("family_ledger", "shared_expense").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .drop_column(FamilyLedger::SharedExpense)
                        .to_owned(),
                )
                .await?;
        }

        // 删除总支出字段
        if manager.has_column("family_ledger", "total_expense").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .drop_column(FamilyLedger::TotalExpense)
                        .to_owned(),
                )
                .await?;
        }

        // 删除总收入字段
        if manager.has_column("family_ledger", "total_income").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .drop_column(FamilyLedger::TotalIncome)
                        .to_owned(),
                )
                .await?;
        }

        Ok(())
    }
}
