use sea_orm_migration::prelude::*;
use std::collections::HashMap;

use crate::schema::Categories;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 categories 表（包含 icon 字段）
        manager
            .create_table(
                Table::create()
                    .table(Categories::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Categories::Name)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Categories::Icon).string().null())
                    .col(
                        ColumnDef::new(Categories::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Categories::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_categories_name")
                    .table(Categories::Table)
                    .col(Categories::Name)
                    .unique()
                    .to_owned(),
            )
            .await?;

        // 定义分类及其图标
        let categories: HashMap<&str, &str> = [
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

        // 插入初始数据（使用 on_conflict 避免重复插入）
        for (name, icon) in categories {
            let insert = Query::insert()
                .into_table(Categories::Table)
                .columns([
                    Categories::Name,
                    Categories::Icon,
                    Categories::CreatedAt,
                    Categories::UpdatedAt,
                ])
                .values_panic([
                    name.into(),
                    icon.into(),
                    Expr::current_timestamp().into(),
                    Expr::current_timestamp().into(),
                ])
                .on_conflict(
                    sea_query::OnConflict::column(Categories::Name)
                        .do_nothing()
                        .to_owned()
                )
                .to_owned();
            manager.exec_stmt(insert).await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_categories_name").to_owned())
            .await?;

        manager
            .drop_table(Table::drop().table(Categories::Table).to_owned())
            .await?;

        Ok(())
    }
}
