use sea_orm_migration::prelude::*;

use crate::schema::Todo;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let alter_stmt_type = Table::alter()
            .table(Todo::Table)
            .drop_column(Todo::Repeat)
            .to_owned();

        manager.alter_table(alter_stmt_type).await?;
        Ok(())
    }

    async fn down(&self, _manager: &SchemaManager) -> Result<(), DbErr> {
        Ok(())
    }
}
