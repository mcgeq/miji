use sea_orm_migration::prelude::*;

use crate::money_scheme::{Account, Currency, Transaction, TransactionStatus, TransactionType};

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
                            .custom(TransactionType::Type)
                            .not_null()
                            .default("Expense"),
                    )
                    .col(
                        ColumnDef::new(Transaction::TransactionStatus)
                            .custom(TransactionStatus::Type)
                            .not_null()
                            .default("Completed"),
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
                        ColumnDef::new(Transaction::CounterpartyAccountId)
                            .string_len(38)
                            .null(),
                    )
                    .col(ColumnDef::new(Transaction::Category).string().not_null())
                    .col(ColumnDef::new(Transaction::SubCategory).string().null())
                    .col(ColumnDef::new(Transaction::Tags).json_binary().null())
                    .col(
                        ColumnDef::new(Transaction::SplitMembers)
                            .json_binary()
                            .null(),
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
