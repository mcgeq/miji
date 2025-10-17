use sea_orm_migration::prelude::*;

use crate::schema::Transactions;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加分期相关字段到 transactions 表
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(ColumnDef::new(Transactions::FirstDueDate).date().null())
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(
                        ColumnDef::new(Transactions::InstallmentAmount)
                            .decimal_len(15, 2)
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
                        ColumnDef::new(Transactions::RemainingPeriodsAmount)
                            .decimal_len(15, 2)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除分期相关字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::FirstDueDate)
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::InstallmentAmount)
                    .to_owned(),
            )
            .await?;

        // 删除 total_periods 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::RemainingPeriodsAmount)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
