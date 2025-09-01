use sea_orm_migration::prelude::*;

use crate::schema::{Account, Currency, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
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
                            .default("Pending")
                            .check(Expr::col(Transactions::TransactionStatus).is_in(vec![
                                "Pending",
                                "Completed",
                                "Reversed",
                            ])),
                    )
                    .col(ColumnDef::new(Transactions::Date).string().not_null())
                    .col(ColumnDef::new(Transactions::Amount).decimal_len(16, 4).not_null())
                    .col(ColumnDef::new(Transactions::RefundAmount).decimal_len(16, 4).not_null().default(0.0))
                    .col(
                        ColumnDef::new(Transactions::Currency)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(currency) <= 10")),
                    )
                    .col(
                        ColumnDef::new(Transactions::Description)
                            .text()
                            .not_null()
                            .check(Expr::cust("LENGTH(description) <= 1000")),
                    )
                    .col(
                        ColumnDef::new(Transactions::Notes)
                            .text()
                            .check(Expr::cust("LENGTH(notes) <= 2000")),
                    )
                    .col(
                        ColumnDef::new(Transactions::AccountSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(ColumnDef::new(Transactions::ToAccountSerialNum).string_len(38))
                    .col(
                        ColumnDef::new(Transactions::Category)
                            .string()
                            .not_null()
                            .check(Expr::col(Transactions::Category).is_in(vec![
                                "Food",
                                "Transport",
                                "Entertainment",
                                "Utilities",
                                "Shopping",
                                "Salary",
                                "Investment",
                                "Transfer",
                                "Education",
                                "Healthcare",
                                "Insurance",
                                "Savings",
                                "Gift",
                                "Loan",
                                "Business",
                                "Travel",
                                "Charity",
                                "Subscription",
                                "Pet",
                                "Home",
                                "Others",
                            ])),
                    )
                    .col(
                        ColumnDef::new(Transactions::SubCategory).string().check(
                            Expr::col(Transactions::SubCategory)
                                .is_in(vec![
                                    "Restaurant",
                                    "Groceries",
                                    "Snacks",
                                    "Bus",
                                    "Taxi",
                                    "Fuel",
                                    "Movies",
                                    "Concerts",
                                    "MonthlySalary",
                                    "Bonus",
                                    "Other",
                                ])
                                .or(Expr::col(Transactions::SubCategory).is_null()),
                        ),
                    )
                    .col(
                        ColumnDef::new(Transactions::Tags)
                            .string()
                            .check(Expr::cust("LENGTH(tags) <= 500")),
                    )
                    .col(ColumnDef::new(Transactions::SplitMembers).string())
                    .col(
                        ColumnDef::new(Transactions::PaymentMethod)
                            .string()
                            .not_null()
                            .default("Cash")
                            .check(Expr::col(Transactions::PaymentMethod).is_in(vec![
                                "Savings",
                                "Cash",
                                "BankTransfer",
                                "CreditCard",
                                "WeChat",
                                "Alipay",
                                "Other",
                            ])),
                    )
                    .col(
                        ColumnDef::new(Transactions::ActualPayerAccount)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(actual_payer_account) <= 38")),
                    )
                    .col(
                        ColumnDef::new(Transactions::RelatedTransactionSerialNum)
                            .string()
                            .check(Expr::cust("LENGTH(related_transaction_serial_num) <= 38")),
                    )
                    .col(
                        ColumnDef::new(Transactions::IsDeleted)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Transactions::IsDeleted).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(Transactions::CreatedAt).string().not_null())
                    .col(ColumnDef::new(Transactions::UpdatedAt).string())
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
