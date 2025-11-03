use sea_orm_migration::prelude::*;

use crate::schema::Account;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 添加 is_virtual 字段
        let alter_stmt = Table::alter()
            .table(Account::Table)
            .add_column(
                ColumnDef::new(Account::IsVirtual)
                    .boolean()
                    .not_null()
                    .default(false),
            )
            .to_owned();
        manager.alter_table(alter_stmt).await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除 is_virtual 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Account::Table)
                    .drop_column(Account::IsVirtual)
                    .to_owned(),
            )
            .await?;
        Ok(())
    }
}
