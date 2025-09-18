use crate::schema::Categories;
use sea_orm_migration::prelude::*;
use std::collections::HashMap;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 1. 添加 icon 字段（允许 NULL，后续填充）
        let alter_stmt = Table::alter()
            .table(Categories::Table)
            .add_column(ColumnDef::new(Categories::Icon).string().null())
            .to_owned();
        manager.alter_table(alter_stmt).await?;

        // 2. 定义历史分类名称与图标的映射（根据需求自定义）
        let icon_mappings: HashMap<&str, &str> = [
            ("Food", "🍔"),
            ("Transport", "🚌"),
            ("Entertainment", "🎬"),
            ("Utilities", "💡"),
            ("Shopping", "🛒"),
            ("Salary", "💰"),
            ("Investment", "📈"),
            ("Transfer", "💸"),
            ("Education", "🎓"),
            ("Healthcare", "⚕️"),
            ("Insurance", "🛡️"),
            ("Savings", "🏦"),
            ("Gift", "🎁"),
            ("Loan", "💳"),
            ("Business", "🏢"),
            ("Travel", "✈️"),
            ("Charity", "❤️"),
            ("Subscription", "📰"),
            ("Pet", "🐶"),
            ("Home", "🏠"),
            ("Others", "❓"),
        ]
        .iter()
        .cloned()
        .collect();

        // 3. 批量更新历史数据的 icon 字段
        for (name, icon) in icon_mappings {
            let update_stmt = Query::update()
                .table(Categories::Table)
                .value(Categories::Icon, Expr::value(icon))
                .and_where(Expr::col(Categories::Name).eq(name))
                .to_owned();
            manager.exec_stmt(update_stmt).await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚时删除 icon 字段（谨慎操作，会丢失所有 icon 数据）
        manager
            .alter_table(
                Table::alter()
                    .table(Categories::Table)
                    .drop_column(Categories::Icon)
                    .to_owned(),
            )
            .await?;
        Ok(())
    }
}
