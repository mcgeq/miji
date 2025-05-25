use sea_orm_migration::prelude::*;

use crate::{schema::Todo, user_scheme::User};

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
                    .col(ColumnDef::new(Todo::Description).text().null())
                    .col(
                        ColumnDef::new(Todo::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Todo::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(Todo::DueAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Todo::Priority)
                            .small_integer()
                            .not_null()
                            .check(Expr::col(Todo::Priority).is_in([0, 1, 2, 3]))
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(Todo::Status)
                            .small_integer()
                            .check(Expr::col(Todo::Status).is_in([0, 1, 2, 3, 4]))
                            .not_null()
                            .default(0),
                    )
                    .col(ColumnDef::new(Todo::Repeat).string().null())
                    .col(
                        ColumnDef::new(Todo::CompletedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(ColumnDef::new(Todo::AssigneeId).string_len(38).null())
                    .col(
                        ColumnDef::new(Todo::Progress)
                            .small_unsigned()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Todo::Progress).lte(100)),
                    )
                    .col(ColumnDef::new(Todo::Location).string().null())
                    .col(ColumnDef::new(Todo::OwnerId).string_len(38).null())
                    .col(
                        ColumnDef::new(Todo::IsArchived)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(Todo::IsPinned)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(Todo::EstimateMinutes).integer().null())
                    .col(
                        ColumnDef::new(Todo::ReminderCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(ColumnDef::new(Todo::ParentId).string_len(38).null())
                    .col(ColumnDef::new(Todo::SubtaskOrder).integer().null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_todo_owner")
                            .from(Todo::Table, Todo::OwnerId)
                            .to(User::Table, User::SerialNum)
                            .on_delete(ForeignKeyAction::SetNull)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建 todos 表索引
        manager
            .create_index(
                Index::create()
                    .name("idx_todo_due_date")
                    .table(Todo::Table)
                    .col(Todo::DueAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_status")
                    .table(Todo::Table)
                    .col(Todo::Status)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_priority")
                    .table(Todo::Table)
                    .col(Todo::Priority)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_todo_created_at")
                    .table(Todo::Table)
                    .col(Todo::CreatedAt)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("idx_todo_created_at")
                    .table(Todo::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_todo_priority")
                    .table(Todo::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_todo_status")
                    .table(Todo::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_todo_due_date")
                    .table(Todo::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(Todo::Table).to_owned())
            .await?;

        Ok(())
    }
}
