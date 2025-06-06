use sea_orm_migration::prelude::*;

use crate::money_scheme::{Account, Currency, Transaction};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Transaction::Table)
                    .col(
                        ColumnDef::new(Transaction::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(Transaction::TransactionType)
                            .tiny_integer()
                            .not_null()
                            .check(Expr::col(Transaction::TransactionType).is_in([0, 1, 2, 3, 4]))
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Transaction::TransactionStatus)
                            .tiny_integer()
                            .not_null()
                            .check(Expr::col(Transaction::TransactionStatus).is_in([0, 1, 2]))
                            .default(0),
                    )
                    .col(ColumnDef::new(Transaction::Date).date().not_null())
                    .col(ColumnDef::new(Transaction::Amount).decimal().not_null())
                    .col(ColumnDef::new(Transaction::Currency).string().not_null())
                    .col(ColumnDef::new(Transaction::Description).string().not_null())
                    .col(ColumnDef::new(Transaction::Notes).text())
                    .col(
                        ColumnDef::new(Transaction::AccountSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Transaction::Category)
                            .small_unsigned()
                            .not_null(),
                    )
                    .col(ColumnDef::new(Transaction::SubCategory).string().null())
                    .col(ColumnDef::new(Transaction::Tags).json_binary().null())
                    .col(
                        ColumnDef::new(Transaction::SplitMembers)
                            .json_binary()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(Transaction::PaymentMethod)
                            .small_unsigned()
                            .not_null()
                            .check(Expr::col(Transaction::PaymentMethod).is_in([0, 1, 2, 3, 4, 5]))
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Transaction::ActualPayerAccount)
                            .small_unsigned()
                            .not_null()
                            .check(Expr::col(Transaction::ActualPayerAccount).is_in([0, 1, 2, 3])),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(Transaction::Table, Transaction::Currency)
                            .to(Currency::Table, Currency::Code),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(Transaction::Table, Transaction::AccountSerialNum)
                            .to(Account::Table, Account::SerialNum),
                    )
                    .to_owned(),
            )
            .await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Transaction::Table).to_owned())
            .await?;
        Ok(())
    }
}
