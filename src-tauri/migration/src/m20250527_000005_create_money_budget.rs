use sea_orm_migration::prelude::*;

use crate::money_scheme::{Account, Budget};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Budget::Table)
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
                    .col(ColumnDef::new(Budget::Name).string().not_null())
                    .col(ColumnDef::new(Budget::Category).string().not_null())
                    .col(
                        ColumnDef::new(Budget::Amount)
                            .decimal()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Budget::RepeatPeriod)
                            .tiny_integer()
                            .not_null()
                            .check(Expr::col(Budget::RepeatPeriod).is_in([0, 1, 2, 3, 4]))
                            .default(0),
                    )
                    .col(ColumnDef::new(Budget::StartDate).date().not_null())
                    .col(ColumnDef::new(Budget::EndDate).date().not_null())
                    .col(
                        ColumnDef::new(Budget::UsedAmount)
                            .decimal()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Budget::IsActive)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(Budget::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_budget_acccount")
                            .from(Budget::Table, Budget::AccountSerialNum)
                            .to(Account::Table, Account::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Budget::Table).to_owned())
            .await?;
        Ok(())
    }
}
