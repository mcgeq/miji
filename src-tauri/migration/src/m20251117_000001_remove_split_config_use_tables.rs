use sea_orm_migration::prelude::*;

use crate::schema::Transactions;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除 split_config JSON 字段，改用 split_records 表
        // 注意：执行此迁移前，需要先将现有的 split_config 数据迁移到 split_records 表
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::SplitConfig)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚：重新添加 split_config 字段
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(
                        ColumnDef::new(Transactions::SplitConfig)
                            .json_binary()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
