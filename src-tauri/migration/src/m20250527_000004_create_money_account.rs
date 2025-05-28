use sea_orm_migration::prelude::*;

use crate::money_scheme::{Account, Currency, FamilyMember};

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
                        ColumnDef::new(Account::AccountType)
                            .tiny_integer()
                            .not_null()
                            .check(Expr::col(Account::AccountType).is_in([0, 1, 2, 3, 4, 5]))
                            .default(0),
                    )
                    .col(ColumnDef::new(Account::Description).string().not_null())
                    .col(
                        ColumnDef::new(Account::Balance)
                            .decimal()
                            .not_null()
                            .default(0),
                    )
                    .col(ColumnDef::new(Account::Currency).string().not_null())
                    .col(
                        ColumnDef::new(Account::IsShared)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(Account::OwnerId).string_len(38).not_null())
                    .col(
                        ColumnDef::new(Account::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Account::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(Account::Table, Account::Currency)
                            .to(Currency::Table, Currency::Code),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(Account::Table, Account::OwnerId)
                            .to(FamilyMember::Table, FamilyMember::SerialNum),
                    )
                    .to_owned(),
            )
            .await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Account::Table).to_owned())
            .await?;
        Ok(())
    }
}
