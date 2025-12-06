use sea_orm_migration::prelude::*;

use crate::schema::UserSettingProfiles;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 user_setting_profiles 表 - 支持多配置切换
        manager
            .create_table(
                Table::create()
                    .table(UserSettingProfiles::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(UserSettingProfiles::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(UserSettingProfiles::UserSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(UserSettingProfiles::ProfileName)
                            .string()
                            .not_null()
                            .comment("配置文件名称，如: 默认、工作、家庭"),
                    )
                    .col(
                        ColumnDef::new(UserSettingProfiles::ProfileData)
                            .json()
                            .not_null()
                            .comment("完整的设置配置数据"),
                    )
                    .col(
                        ColumnDef::new(UserSettingProfiles::IsActive)
                            .boolean()
                            .not_null()
                            .default(false)
                            .comment("是否为当前激活的配置"),
                    )
                    .col(
                        ColumnDef::new(UserSettingProfiles::IsDefault)
                            .boolean()
                            .not_null()
                            .default(false)
                            .comment("是否为默认配置（不可删除）"),
                    )
                    .col(
                        ColumnDef::new(UserSettingProfiles::Description)
                            .string()
                            .null()
                            .comment("配置描述"),
                    )
                    .col(
                        ColumnDef::new(UserSettingProfiles::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(UserSettingProfiles::UpdatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建唯一索引 - 每个用户的配置名称唯一
        manager
            .create_index(
                Index::create()
                    .name("idx_user_setting_profiles_unique_name")
                    .table(UserSettingProfiles::Table)
                    .col(UserSettingProfiles::UserSerialNum)
                    .col(UserSettingProfiles::ProfileName)
                    .unique()
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建激活配置索引
        manager
            .create_index(
                Index::create()
                    .name("idx_user_setting_profiles_active")
                    .table(UserSettingProfiles::Table)
                    .col(UserSettingProfiles::UserSerialNum)
                    .col(UserSettingProfiles::IsActive)
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
                    .name("idx_user_setting_profiles_active")
                    .table(UserSettingProfiles::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_user_setting_profiles_unique_name")
                    .table(UserSettingProfiles::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(UserSettingProfiles::Table).to_owned())
            .await?;

        Ok(())
    }
}
