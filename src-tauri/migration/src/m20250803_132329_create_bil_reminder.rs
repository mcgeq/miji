use sea_orm_migration::prelude::*;

use crate::schema::{BilReminder, Transactions};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(BilReminder::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(BilReminder::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(BilReminder::Name).string().not_null())
                    .col(
                        ColumnDef::new(BilReminder::Enabled)
                            .integer()
                            .not_null()
                            .default(1)
                            .check(Expr::col(BilReminder::Enabled).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(BilReminder::Type).string().not_null().check(
                        Expr::col(BilReminder::Type).is_in(vec!["Notification", "Email", "Popup"]),
                    ))
                    .col(
                        ColumnDef::new(BilReminder::Description)
                            .text()
                            .not_null()
                            .check(Expr::cust("LENGTH(description) <= 1000")),
                    )
                    .col(
                        ColumnDef::new(BilReminder::Category)
                            .string()
                            .not_null()
                            .check(Expr::col(BilReminder::Category).is_in(vec![
                                "Food",
                                "Transport",
                                "Entertainment",
                                "Utilities",
                                "Shopping",
                                "Salary",
                                "Investment",
                                "Others",
                            ])),
                    )
                    .col(
                        ColumnDef::new(BilReminder::Amount)
                            .string()
                            .not_null()
                            .check(Expr::cust("amount GLOB '[0-9]*\\.?[0-9]*'")),
                    )
                    .col(
                        ColumnDef::new(BilReminder::Currency)
                            .string()
                            .not_null()
                            .check(Expr::cust("LENGTH(currency) <= 10")),
                    )
                    .col(ColumnDef::new(BilReminder::DueAt).string().not_null())
                    .col(ColumnDef::new(BilReminder::BillDate).string().not_null())
                    .col(ColumnDef::new(BilReminder::RemindDate).string().not_null())
                    .col(
                        ColumnDef::new(BilReminder::RepeatPeriod)
                            .string()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(BilReminder::IsPaid)
                            .integer()
                            .not_null()
                            .default(1)
                            .check(Expr::col(BilReminder::IsPaid).is_in(vec![0, 1])),
                    )
                    .col(
                        ColumnDef::new(BilReminder::Priority)
                            .string()
                            .not_null()
                            .default("Low")
                            .check(
                                Expr::col(BilReminder::Priority)
                                    .is_in(vec!["Low", "Medium", "High", "Urgent"]),
                            ),
                    )
                    .col(ColumnDef::new(BilReminder::AdvanceValue).integer())
                    .col(ColumnDef::new(BilReminder::AdvanceUnit).string())
                    .col(ColumnDef::new(BilReminder::RelatedTransactionSerialNum).string_len(38))
                    .col(ColumnDef::new(BilReminder::Color).string())
                    .col(
                        ColumnDef::new(BilReminder::IsDeleted)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(BilReminder::IsDeleted).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(BilReminder::CreatedAt).string().not_null())
                    .col(ColumnDef::new(BilReminder::UpdatedAt).string())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_bil_reminder_transaction")
                            .from(BilReminder::Table, BilReminder::RelatedTransactionSerialNum)
                            .to(Transactions::Table, Transactions::SerialNum)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_bil_reminder_due_at")
                    .table(BilReminder::Table)
                    .col(BilReminder::DueAt)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_bil_reminder_paid")
                    .table(BilReminder::Table)
                    .col(BilReminder::IsPaid)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_bil_reminder_due_at").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_bil_reminder_paid").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(BilReminder::Table).to_owned())
            .await?;

        Ok(())
    }
}
