use sea_orm_migration::prelude::*;

use crate::schema::{Account, InstallmentDetails, InstallmentPlans};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 installment_details 表
        manager
            .create_table(
                Table::create()
                    .table(InstallmentDetails::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(InstallmentDetails::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::PlanSerialNum)
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
                            .date()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::Amount)
                            .decimal_len(15, 2)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::AccountSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::Status)
                            .string()
                            .default("PENDING"),
                    )
                    .col(ColumnDef::new(InstallmentDetails::PaidDate).date().null())
                    .col(
                        ColumnDef::new(InstallmentDetails::PaidAmount)
                            .decimal_len(15, 2)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(InstallmentDetails::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    // 外键约束
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_installment_details_plan")
                            .from(InstallmentDetails::Table, InstallmentDetails::PlanSerialNum)
                            .to(InstallmentPlans::Table, InstallmentPlans::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_installment_details_account")
                            .from(
                                InstallmentDetails::Table,
                                InstallmentDetails::AccountSerialNum,
                            )
                            .to(Account::Table, Account::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
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
                    .col(InstallmentDetails::PlanSerialNum)
                    .col(InstallmentDetails::PeriodNumber)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_installment_details_account")
                    .table(InstallmentDetails::Table)
                    .col(InstallmentDetails::AccountSerialNum)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_installment_details_status")
                    .table(InstallmentDetails::Table)
                    .col(InstallmentDetails::Status)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("idx_installment_details_status")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_installment_details_account")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_installment_details_plan_period")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(InstallmentDetails::Table).to_owned())
            .await?;

        Ok(())
    }
}
