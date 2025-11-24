use sea_orm_migration::prelude::*;

use crate::schema::Currency;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 currency 表（包含所有字段）
        manager
            .create_table(
                Table::create()
                    .table(Currency::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Currency::Code)
                            .string_len(3)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Currency::Locale).string().not_null())
                    .col(ColumnDef::new(Currency::Symbol).string_len(10).not_null())
                    .col(
                        ColumnDef::new(Currency::IsDefault)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(Currency::IsActive)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(Currency::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Currency::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 插入初始货币数据（使用循环避免 SQLite 批量插入 + on_conflict 兼容性问题）
        let currencies = vec![
            ("USD", "en-US", "$", false),
            ("EUR", "en-EU", "€", false),
            ("CNY", "zh-CN", "¥", true), // CNY 设置为默认货币
            ("GBP", "en-GB", "£", false),
            ("JPY", "ja-JP", "¥", false),
            ("AUD", "en-AU", "$", false),
            ("CAD", "en-CA", "$", false),
            ("CHF", "en-CH", "CHF", false),
            ("SEK", "sv-SE", "kr", false),
            ("INR", "hi-IN", "₹", false),
        ];

        for (code, locale, symbol, is_default) in currencies {
            manager
                .exec_stmt(
                    Query::insert()
                        .into_table(Currency::Table)
                        .columns([
                            Currency::Code,
                            Currency::Locale,
                            Currency::Symbol,
                            Currency::IsDefault,
                            Currency::IsActive,
                            Currency::CreatedAt,
                        ])
                        .values_panic([
                            code.into(),
                            locale.into(),
                            symbol.into(),
                            is_default.into(),
                            true.into(),
                            "2025-07-26T13:13:24.487000+08:00".into(),
                        ])
                        .on_conflict(
                            sea_query::OnConflict::column(Currency::Code)
                                .do_nothing()
                                .to_owned(),
                        )
                        .to_owned(),
                )
                .await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Currency::Table).to_owned())
            .await?;

        Ok(())
    }
}
