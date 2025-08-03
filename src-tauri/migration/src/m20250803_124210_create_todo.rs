use sea_orm_migration::prelude::*;

use crate::schema::{Todo, Users};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Todo::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Todo::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Todo::Title).string().not_null())
                    .col(
                        ColumnDef::new(Todo::Description)
                            .text()
                            .check(Expr::cust("LENGTH(description) <= 1000")),
                    )
                    .col(ColumnDef::new(Todo::CreatedAt).string().not_null())
                    .col(ColumnDef::new(Todo::UpdatedAt).string())
                    .col(ColumnDef::new(Todo::DueAt).string().not_null())
                    .col(
                        ColumnDef::new(Todo::Priority)
                            .string()
                            .not_null()
                            .default("Low")
                            .check(
                                Expr::col(Todo::Priority)
                                    .is_in(vec!["Low", "Medium", "High", "Urgent"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(Todo::Status)
                            .string()
                            .not_null()
                            .default("NotStarted")
                            .check(Expr::col(Todo::Status).is_in(vec![
                                "NotStarted",
                                "InProgress",
                                "Completed",
                                "Cancelled",
                                "Overdue",
                            ])),
                    )
                    .col(ColumnDef::new(Todo::Repeat).string())
                    .col(ColumnDef::new(Todo::CompletedAt).string())
                    .col(
                        ColumnDef::new(Todo::AssigneeId)
                            .string()
                            .check(Expr::cust("LENGTH(assignee_id) <= 38")),
                    )
                    .col(
                        ColumnDef::new(Todo::Progress)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::cust("progress BETWEEN 0 AND 100")),
                    )
                    .col(ColumnDef::new(Todo::Location).string())
                    .col(
                        ColumnDef::new(Todo::OwnerId)
                            .string()
                            .check(Expr::cust("LENGTH(owner_id) <= 38")),
                    )
                    .col(
                        ColumnDef::new(Todo::IsArchived)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Todo::IsArchived).is_in(vec![0, 1])),
                    )
                    .col(
                        ColumnDef::new(Todo::IsPinned)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Todo::IsPinned).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(Todo::EstimateMinutes).integer())
                    .col(
                        ColumnDef::new(Todo::ReminderCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Todo::ParentId)
                            .string()
                            .check(Expr::cust("LENGTH(parent_id) <= 38")),
                    )
                    .col(ColumnDef::new(Todo::SubtaskOrder).integer())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_todo_owner")
                            .from(Todo::Table, Todo::OwnerId)
                            .to(Users::Table, Users::SerialNum)
                            .on_delete(ForeignKeyAction::SetNull)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_due_date")
                    .table(Todo::Table)
                    .col(Todo::DueAt)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_status")
                    .table(Todo::Table)
                    .col(Todo::Status)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_priority")
                    .table(Todo::Table)
                    .col(Todo::Priority)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_created_at")
                    .table(Todo::Table)
                    .col(Todo::CreatedAt)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_owner_id")
                    .table(Todo::Table)
                    .col(Todo::OwnerId)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_parent_id")
                    .table(Todo::Table)
                    .col(Todo::ParentId)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_todo_due_date").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_todo_status").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_todo_priority").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_todo_created_at").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_todo_owner_id").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_todo_parent_id").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Todo::Table).to_owned())
            .await?;

        Ok(())
    }
}
