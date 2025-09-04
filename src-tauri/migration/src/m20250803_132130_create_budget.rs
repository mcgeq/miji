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
                            .null(),
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
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.0),
                    )
                    .col(ColumnDef::new(Budget::Currency).string_len(3).not_null())
                    .col(
                        ColumnDef::new(Budget::RepeatPeriod)
                            .json_binary()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::StartDate)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::EndDate)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::UsedAmount)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.0),
                    )
                    .col(
                        ColumnDef::new(Budget::IsActive)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(Budget::AlertEnabled)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(Budget::AlertThreshold).json_binary().null())
                    .col(ColumnDef::new(Budget::Color).string_len(7).null())
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
                    .col(
                        ColumnDef::new(Budget::CurrentPeriodUsed)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.0),
                    )
                    .col(ColumnDef::new(Budget::CurrentPeriodStart).date().not_null())
                    .col(
                        ColumnDef::new(Budget::LastResetAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::BudgetType)
                            .string_len(20)
                            .not_null()
                            .default("Standard"),
                    )
                    .col(
                        ColumnDef::new(Budget::Progress)
                            .decimal_len(3, 2)
                            .not_null()
                            .default(0.0),
                    )
                    .col(ColumnDef::new(Budget::LinkedGoal).string().null())
                    .col(ColumnDef::new(Budget::Reminders).json_binary().null())
                    .col(
                        ColumnDef::new(Budget::Priority)
                            .tiny_integer()
                            .not_null()
                            .default(3),
                    )
                    .col(ColumnDef::new(Budget::Tags).json().null())
                    .col(
                        ColumnDef::new(Budget::AutoRollover)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(Budget::RolloverHistory).json_binary().null())
                    .col(ColumnDef::new(Budget::SharingSettings).json_binary().null())
                    .col(ColumnDef::new(Budget::Attachments).json_binary().null())
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

        manager
            .create_index(
                Index::create()
                    .name("idx_budget_type")
                    .table(Budget::Table)
                    .col(Budget::BudgetType)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_budget_active")
                    .table(Budget::Table)
                    .col(Budget::IsActive)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_budget_start_date")
                    .table(Budget::Table)
                    .col(Budget::StartDate)
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
            .drop_index(Index::drop().name("idx_budget_type").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_budget_active").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_budget_start_date").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Budget::Table).to_owned())
            .await?;

        Ok(())
    }
}
