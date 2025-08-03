use sea_orm_migration::prelude::*;

use crate::schema::{Account, Currency, FamilyMember};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Account::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Account::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(Account::Name)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(name) <= 200")),
                    )
                    .col(
                        ColumnDef::new(Account::Description)
                            .text()
                            .not_null()
                            .check(Expr::cust("LENGTH(description) <= 1000")),
                    )
                    .col(ColumnDef::new(Account::Type).string().not_null().check(
                        Expr::col(Account::Type).is_in(vec![
                            "Savings",
                            "Cash",
                            "Bank",
                            "CreditCard",
                            "Investment",
                            "Alipay",
                            "WeChat",
                            "CloudQuickPass",
                            "Other",
                        ]),
                    ))
                    .col(
                        ColumnDef::new(Account::Balance)
                            .decimal()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Account::InitialBalance)
                            .decimal()
                            .not_null()
                            .default(0),
                    )
                    .col(ColumnDef::new(Account::Currency).string_len(3).not_null())
                    .col(
                        ColumnDef::new(Account::IsShared)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Account::IsShared).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(Account::OwnerId).string_len(38))
                    .col(ColumnDef::new(Account::Color).string())
                    .col(
                        ColumnDef::new(Account::IsActive)
                            .integer()
                            .not_null()
                            .default(1)
                            .check(Expr::col(Account::IsActive).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(Account::CreatedAt).string().not_null())
                    .col(ColumnDef::new(Account::UpdatedAt).string())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_account_currency")
                            .from(Account::Table, Account::Currency)
                            .to(Currency::Table, Currency::Code)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_account_owner")
                            .from(Account::Table, Account::OwnerId)
                            .to(FamilyMember::Table, FamilyMember::SerialNum)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_account_owner")
                    .table(Account::Table)
                    .col(Account::OwnerId)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_account_currency")
                    .table(Account::Table)
                    .col(Account::Currency)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_account_owner").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_account_currency").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Account::Table).to_owned())
            .await?;

        Ok(())
    }
}
