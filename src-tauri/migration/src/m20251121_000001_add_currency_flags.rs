use sea_orm_migration::prelude::*;

use crate::schema::Currency;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 1. 添加 is_default 字段，默认值为 false
        manager
            .alter_table(
                Table::alter()
                    .table(Currency::Table)
                    .add_column(
                        ColumnDef::new(Currency::IsDefault)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .to_owned(),
            )
            .await?;

        // 2. 添加 is_active 字段，默认值为 true
        manager
            .alter_table(
                Table::alter()
                    .table(Currency::Table)
                    .add_column(
                        ColumnDef::new(Currency::IsActive)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .to_owned(),
            )
            .await?;

        // 3. 将 CNY 设置为默认货币
        manager
            .exec_stmt(
                Query::update()
                    .table(Currency::Table)
                    .value(Currency::IsDefault, true)
                    .and_where(Expr::col(Currency::Code).eq("CNY"))
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚时删除添加的字段
        manager
            .alter_table(
                Table::alter()
                    .table(Currency::Table)
                    .drop_column(Currency::IsDefault)
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Currency::Table)
                    .drop_column(Currency::IsActive)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
