use sea_orm_migration::prelude::*;

use crate::schema::{Reminder, Todo};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Reminder::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Reminder::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(Reminder::TodoSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(ColumnDef::new(Reminder::RemindAt).date_time().not_null())
                    .col(ColumnDef::new(Reminder::Type).integer())
                    .col(
                        ColumnDef::new(Reminder::IsSent)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Reminder::IsSent).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(Reminder::CreatedAt).string().not_null())
                    .col(ColumnDef::new(Reminder::UpdatedAt).string())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_reminder_todo")
                            .from(Reminder::Table, Reminder::TodoSerialNum)
                            .to(Todo::Table, Todo::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_todo")
                    .table(Reminder::Table)
                    .col(Reminder::TodoSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_reminder_remind_at")
                    .table(Reminder::Table)
                    .col(Reminder::RemindAt)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_reminder_todo").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_reminder_remind_at").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Reminder::Table).to_owned())
            .await?;

        Ok(())
    }
}
