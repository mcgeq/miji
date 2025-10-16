use sea_orm_migration::prelude::*;

use crate::schema::{InstallmentDetails, InstallmentPlans, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
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
                        ColumnDef::new(Transactions::InstallmentPlanId)
                            .string_len(38)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建分期付款计划表
        manager
            .create_table(
                Table::create()
                    .table(InstallmentPlans::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(InstallmentPlans::Id)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::TransactionId)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::TotalAmount)
                            .decimal_len(15, 2)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::TotalPeriods)
                            .integer()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::InstallmentAmount)
                            .decimal_len(15, 2)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::FirstDueDate)
                            .date_time()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::Status)
                            .string()
                            .default("ACTIVE"),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::CreatedAt)
                            .date_time()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::UpdatedAt)
                            .date_time()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_installment_plans_transaction_id")
                            .from(InstallmentPlans::Table, InstallmentPlans::TransactionId)
                            .to(Transactions::Table, Transactions::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建分期付款明细表
        manager
            .create_table(
                Table::create()
                    .table(InstallmentDetails::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(InstallmentDetails::Id)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::PlanId)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::PeriodNumber)
                            .integer()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::DueDate)
                            .date_time()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::Amount)
                            .decimal_len(15, 2)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::Status)
                            .string()
                            .default("PENDING"),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::PaidDate)
                            .date_time()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::PaidAmount)
                            .decimal_len(15, 2)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::CreatedAt)
                            .date_time()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::UpdatedAt)
                            .date_time()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_installment_details_plan_id")
                            .from(InstallmentDetails::Table, InstallmentDetails::PlanId)
                            .to(InstallmentPlans::Table, InstallmentPlans::Id)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建唯一索引：每个计划内期数唯一
        manager
            .create_index(
                Index::create()
                    .name("idx_installment_details_plan_period")
                    .table(InstallmentDetails::Table)
                    .col(InstallmentDetails::PlanId)
                    .col(InstallmentDetails::PeriodNumber)
                    .unique()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除分期付款明细表
        manager
            .drop_table(Table::drop().table(InstallmentDetails::Table).to_owned())
            .await?;

        // 删除分期付款计划表
        manager
            .drop_table(Table::drop().table(InstallmentPlans::Table).to_owned())
            .await?;

        // 删除交易表中的新分期相关字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::InstallmentPlanId)
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

        Ok(())
    }
}