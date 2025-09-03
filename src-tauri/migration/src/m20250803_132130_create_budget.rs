use sea_orm_migration::prelude::*;

use crate::schema::{Account, Budget};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Budget::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Budget::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(Budget::AccountSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::Name)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(name) <= 200")),
                    )
                    .col(ColumnDef::new(Budget::Description).string())
                    .col(ColumnDef::new(Budget::Category).string().not_null().check(
                        Expr::col(Budget::Category).is_in(vec![
                            "Food",
                            "Transport",
                            "Entertainment",
                            "Utilities",
                            "Shopping",
                            "Salary",
                            "Investment",
                            "Others",
                        ]),
                    ))
                    .col(
                        ColumnDef::new(Budget::Amount)
                            .decimal()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Budget::Currency)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(currency) <= 10")),
                    )
                    .col(ColumnDef::new(Budget::RepeatPeriod).string().not_null())
                    .col(ColumnDef::new(Budget::StartDate).string().not_null())
                    .col(ColumnDef::new(Budget::EndDate).string().not_null())
                    .col(
                        ColumnDef::new(Budget::UsedAmount)
                            .decimal()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Budget::IsActive)
                            .integer()
                            .not_null()
                            .default(1)
                            .check(Expr::col(Budget::IsActive).is_in(vec![0, 1])),
                    )
                    .col(
                        ColumnDef::new(Budget::AlertEnabled)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Budget::AlertEnabled).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(Budget::AlertThreshold).string())
                    .col(ColumnDef::new(Budget::Color).string())
                    .col(ColumnDef::new(Budget::CreatedAt).string().not_null())
                    .col(ColumnDef::new(Budget::UpdatedAt).string())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_budget_account")
                            .from(Budget::Table, Budget::AccountSerialNum)
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
                    .name("idx_budget_account")
                    .table(Budget::Table)
                    .col(Budget::AccountSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_budget_category")
                    .table(Budget::Table)
                    .col(Budget::Category)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_budget_account").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_budget_category").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Budget::Table).to_owned())
            .await?;

        Ok(())
    }
}
