use sea_orm_migration::prelude::*;

use crate::schema::{InstallmentDetails, InstallmentPlans};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 修改 installment_plans 表的字段类型
        manager
            .alter_table(
                Table::alter()
                    .table(InstallmentPlans::Table)
                    .modify_column(
                        ColumnDef::new(InstallmentPlans::FirstDueDate)
                            .date()
                            .not_null(),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentPlans::CreatedAt)
                            .timestamp_with_time_zone()
                            .default(Expr::current_timestamp()),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentPlans::UpdatedAt)
                            .timestamp_with_time_zone()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        // 修改 installment_details 表的字段类型
        manager
            .alter_table(
                Table::alter()
                    .table(InstallmentDetails::Table)
                    .modify_column(
                        ColumnDef::new(InstallmentDetails::DueDate)
                            .date()
                            .not_null(),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentDetails::PaidDate)
                            .date()
                            .null(),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentDetails::CreatedAt)
                            .timestamp_with_time_zone()
                            .default(Expr::current_timestamp()),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentDetails::UpdatedAt)
                            .timestamp_with_time_zone()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚：将字段类型改回原来的类型
        manager
            .alter_table(
                Table::alter()
                    .table(InstallmentPlans::Table)
                    .modify_column(
                        ColumnDef::new(InstallmentPlans::FirstDueDate)
                            .date_time()
                            .not_null(),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentPlans::CreatedAt)
                            .date_time()
                            .default(Expr::current_timestamp()),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentPlans::UpdatedAt)
                            .date_time()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(InstallmentDetails::Table)
                    .modify_column(
                        ColumnDef::new(InstallmentDetails::DueDate)
                            .date_time()
                            .not_null(),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentDetails::PaidDate)
                            .date_time()
                            .null(),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentDetails::CreatedAt)
                            .date_time()
                            .default(Expr::current_timestamp()),
                    )
                    .modify_column(
                        ColumnDef::new(InstallmentDetails::UpdatedAt)
                            .date_time()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
