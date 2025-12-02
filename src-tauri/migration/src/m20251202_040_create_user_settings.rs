use sea_orm_migration::prelude::*;

use crate::schema::UserSettings;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 user_settings 表
        manager
            .create_table(
                Table::create()
                    .table(UserSettings::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(UserSettings::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(UserSettings::UserSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(UserSettings::SettingKey)
                            .string()
                            .not_null()
                            .comment("设置键名，格式: settings.{module}.{field}"),
                    )
                    .col(
                        ColumnDef::new(UserSettings::SettingValue)
                            .json()
                            .not_null()
                            .comment("设置值，JSON格式支持任意类型"),
                    )
                    .col(
                        ColumnDef::new(UserSettings::SettingType)
                            .string()
                            .not_null()
                            .default("string")
                            .comment("值类型: string, number, boolean, object, array"),
                    )
                    .col(
                        ColumnDef::new(UserSettings::Module)
                            .string()
                            .not_null()
                            .comment("所属模块: general, notification, privacy, security"),
                    )
                    .col(
                        ColumnDef::new(UserSettings::Description)
                            .string()
                            .null()
                            .comment("设置描述"),
                    )
                    .col(
                        ColumnDef::new(UserSettings::IsDefault)
                            .boolean()
                            .not_null()
                            .default(false)
                            .comment("是否为默认值"),
                    )
                    .col(
                        ColumnDef::new(UserSettings::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .comment("创建时间"),
                    )
                    .col(
                        ColumnDef::new(UserSettings::UpdatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .comment("最后更新时间"),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建唯一索引 - 每个用户的每个设置键只能有一条记录
        manager
            .create_index(
                Index::create()
                    .name("idx_user_settings_unique_key")
                    .table(UserSettings::Table)
                    .col(UserSettings::UserSerialNum)
                    .col(UserSettings::SettingKey)
                    .unique()
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建模块索引 - 方便按模块查询
        manager
            .create_index(
                Index::create()
                    .name("idx_user_settings_module")
                    .table(UserSettings::Table)
                    .col(UserSettings::UserSerialNum)
                    .col(UserSettings::Module)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建更新时间索引 - 用于同步和审计
        manager
            .create_index(
                Index::create()
                    .name("idx_user_settings_updated_at")
                    .table(UserSettings::Table)
                    .col(UserSettings::UpdatedAt)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("idx_user_settings_updated_at")
                    .table(UserSettings::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_user_settings_module")
                    .table(UserSettings::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_user_settings_unique_key")
                    .table(UserSettings::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(UserSettings::Table).to_owned())
            .await?;

        Ok(())
    }
}

