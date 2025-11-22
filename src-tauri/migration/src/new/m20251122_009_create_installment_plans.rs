use sea_orm_migration::prelude::*;

use crate::schema::{Account, InstallmentPlans, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 installment_plans 表
        manager
            .create_table(
                Table::create()
                    .table(InstallmentPlans::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(InstallmentPlans::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::TransactionSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::AccountSerialNum)
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
                            .date()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::Status)
                            .string()
                            .default("ACTIVE"),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentPlans::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    // 外键约束
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_installment_plans_transaction")
                            .from(
                                InstallmentPlans::Table,
                                InstallmentPlans::TransactionSerialNum,
                            )
                            .to(Transactions::Table, Transactions::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_installment_plans_account")
                            .from(InstallmentPlans::Table, InstallmentPlans::AccountSerialNum)
                            .to(Account::Table, Account::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_installment_plans_transaction")
                    .table(InstallmentPlans::Table)
                    .col(InstallmentPlans::TransactionSerialNum)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_installment_plans_account")
                    .table(InstallmentPlans::Table)
                    .col(InstallmentPlans::AccountSerialNum)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("idx_installment_plans_account")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_installment_plans_transaction")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(InstallmentPlans::Table).to_owned())
            .await?;

        Ok(())
    }
}
