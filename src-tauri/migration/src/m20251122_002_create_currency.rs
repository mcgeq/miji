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

        // 插入初始货币数据
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
                        "USD".into(),
                        "en-US".into(),
                        "$".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "EUR".into(),
                        "en-EU".into(),
                        "€".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "CNY".into(),
                        "zh-CN".into(),
                        "¥".into(),
                        true.into(), // CNY 设置为默认货币
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "GBP".into(),
                        "en-GB".into(),
                        "£".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "JPY".into(),
                        "ja-JP".into(),
                        "¥".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "AUD".into(),
                        "en-AU".into(),
                        "$".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "CAD".into(),
                        "en-CA".into(),
                        "$".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "CHF".into(),
                        "en-CH".into(),
                        "CHF".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "SEK".into(),
                        "sv-SE".into(),
                        "kr".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .values_panic([
                        "INR".into(),
                        "hi-IN".into(),
                        "₹".into(),
                        false.into(),
                        true.into(),
                        "2025-07-26T13:13:24.487000+08:00".into(),
                    ])
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Currency::Table).to_owned())
            .await?;

        Ok(())
    }
}
