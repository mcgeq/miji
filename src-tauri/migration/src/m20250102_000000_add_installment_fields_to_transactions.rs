use sea_orm_migration::prelude::*;

use crate::schema::Transactions;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加分期相关字段到 transactions 表
        // SQLite 不支持在单个 ALTER TABLE 语句中执行多个操作，需要分开执行
        // 修改交易表，添加新的分期相关字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(
                        ColumnDef::new(Transactions::RemainingPeriods)
                            .integer()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(
                        ColumnDef::new(Transactions::InstallmentPlanSerialNum)
                            .string_len(38)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 添加 is_installment 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(ColumnDef::new(Transactions::IsInstallment).boolean().null())
                    .to_owned(),
            )
            .await?;

        // 添加 total_periods 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(ColumnDef::new(Transactions::TotalPeriods).integer().null())
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除分期相关字段
        // SQLite 不支持在单个 ALTER TABLE 语句中执行多个操作，需要分开执行
        // 删除交易表中的新分期相关字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::InstallmentPlanSerialNum)
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::RemainingPeriods)
                    .to_owned(),
            )
            .await?;

        // 删除 total_periods 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::TotalPeriods)
                    .to_owned(),
            )
            .await?;

        // 删除 is_installment 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::IsInstallment)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
