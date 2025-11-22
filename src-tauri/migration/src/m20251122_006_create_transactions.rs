use sea_orm_migration::prelude::*;

use crate::schema::{Account, Currency, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 transactions 表（包含所有字段，不包含已废弃的 split_config 和 split_members）
        manager
            .create_table(
                Table::create()
                    .table(Transactions::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Transactions::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(Transactions::TransactionType)
                            .string()
                            .not_null()
                            .default("Income")
                            .check(
                                Expr::col(Transactions::TransactionType)
                                    .is_in(vec!["Income", "Expense"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(Transactions::TransactionStatus)
                            .string()
                            .not_null()
                            .default("Pending"),
                    )
                    .col(
                        ColumnDef::new(Transactions::Date)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Transactions::Amount)
                            .decimal_len(16, 4)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Transactions::RefundAmount)
                            .decimal_len(16, 4)
                            .not_null()
                            .default(0.0),
                    )
                    .col(
                        ColumnDef::new(Transactions::Currency)
                            .string_len(3)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Transactions::Description)
                            .string_len(1000)
                            .not_null(),
                    )
                    .col(ColumnDef::new(Transactions::Notes).string_len(2000))
                    .col(
                        ColumnDef::new(Transactions::AccountSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(ColumnDef::new(Transactions::ToAccountSerialNum).string_len(38))
                    .col(ColumnDef::new(Transactions::Category).string().not_null())
                    .col(ColumnDef::new(Transactions::SubCategory).string())
                    .col(ColumnDef::new(Transactions::Tags).json_binary().null())
                    // 注意: split_members 和 split_config 字段已废弃，改用独立的 split_records 表
                    .col(
                        ColumnDef::new(Transactions::PaymentMethod)
                            .string()
                            .not_null()
                            .default("Cash"),
                    )
                    .col(
                        ColumnDef::new(Transactions::ActualPayerAccount)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Transactions::RelatedTransactionSerialNum)
                            .string_len(38)
                            .null(),
                    )
                    // 分期付款相关字段
                    .col(ColumnDef::new(Transactions::IsInstallment).boolean().null())
                    .col(ColumnDef::new(Transactions::TotalPeriods).integer().null())
                    .col(ColumnDef::new(Transactions::RemainingPeriods).integer().null())
                    .col(
                        ColumnDef::new(Transactions::InstallmentPlanSerialNum)
                            .string_len(38)
                            .null(),
                    )
                    .col(ColumnDef::new(Transactions::FirstDueDate).date().null())
                    .col(
                        ColumnDef::new(Transactions::InstallmentAmount)
                            .decimal_len(15, 2)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(Transactions::RemainingPeriodsAmount)
                            .decimal_len(15, 2)
                            .null(),
                    )
                    // 标记字段
                    .col(
                        ColumnDef::new(Transactions::IsDeleted)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(Transactions::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Transactions::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    // 外键约束
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_transaction_currency")
                            .from(Transactions::Table, Transactions::Currency)
                            .to(Currency::Table, Currency::Code)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_transaction_account")
                            .from(Transactions::Table, Transactions::AccountSerialNum)
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
                    .name("idx_transaction_date")
                    .table(Transactions::Table)
                    .col(Transactions::Date)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_transaction_category")
                    .table(Transactions::Table)
                    .col(Transactions::Category)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_transaction_account")
                    .table(Transactions::Table)
                    .col(Transactions::AccountSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_transaction_category_date")
                    .table(Transactions::Table)
                    .col(Transactions::Category)
                    .col(Transactions::Date)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_transaction_date").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_transaction_category").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_transaction_account").to_owned())
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .name("idx_transaction_category_date")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(Table::drop().table(Transactions::Table).to_owned())
            .await?;

        Ok(())
    }
}
