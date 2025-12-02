use sea_orm_migration::prelude::*;

use crate::schema::UserSettingHistory;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 user_setting_history 表 - 审计和恢复
        manager
            .create_table(
                Table::create()
                    .table(UserSettingHistory::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(UserSettingHistory::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::UserSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::SettingKey)
                            .string()
                            .not_null()
                            .comment("设置键名"),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::OldValue)
                            .json()
                            .null()
                            .comment("旧值（null表示新建）"),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::NewValue)
                            .json()
                            .not_null()
                            .comment("新值"),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::ChangeType)
                            .string()
                            .not_null()
                            .comment("变更类型: create, update, delete, reset")
                            .check(
                                Expr::col(UserSettingHistory::ChangeType).is_in(vec![
                                    "create",
                                    "update",
                                    "delete",
                                    "reset",
                                ]),
                            ),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::ChangedBy)
                            .string()
                            .null()
                            .comment("变更来源: user, system, import"),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::IpAddress)
                            .string()
                            .null()
                            .comment("操作IP地址"),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::UserAgent)
                            .text()
                            .null()
                            .comment("用户代理信息"),
                    )
                    .col(
                        ColumnDef::new(UserSettingHistory::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .comment("变更时间"),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建用户+键名索引 - 方便查询某个设置的历史
        manager
            .create_index(
                Index::create()
                    .name("idx_user_setting_history_key")
                    .table(UserSettingHistory::Table)
                    .col(UserSettingHistory::UserSerialNum)
                    .col(UserSettingHistory::SettingKey)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建时间索引 - 方便按时间查询
        manager
            .create_index(
                Index::create()
                    .name("idx_user_setting_history_created_at")
                    .table(UserSettingHistory::Table)
                    .col(UserSettingHistory::CreatedAt)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建用户索引 - 方便查询用户的所有变更
        manager
            .create_index(
                Index::create()
                    .name("idx_user_setting_history_user")
                    .table(UserSettingHistory::Table)
                    .col(UserSettingHistory::UserSerialNum)
                    .col(UserSettingHistory::CreatedAt)
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
                    .name("idx_user_setting_history_user")
                    .table(UserSettingHistory::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_user_setting_history_created_at")
                    .table(UserSettingHistory::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_user_setting_history_key")
                    .table(UserSettingHistory::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(
                Table::drop()
                    .table(UserSettingHistory::Table)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}

