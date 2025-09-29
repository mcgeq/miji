use sea_orm_migration::prelude::*;

use crate::schema::Todo;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let alter_stmt = Table::alter()
            .table(Todo::Table)
            .add_column_if_not_exists(ColumnDef::new(Todo::Repeat).json_binary().not_null())
            .to_owned();

        manager.alter_table(alter_stmt).await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚时删除 icon 字段（谨慎操作，会丢失所有 icon 数据）
        manager
            .alter_table(
                Table::alter()
                    .table(Todo::Table)
                    .drop_column(Todo::Repeat)
                    .to_owned(),
            )
            .await?;
        Ok(())
    }
}
