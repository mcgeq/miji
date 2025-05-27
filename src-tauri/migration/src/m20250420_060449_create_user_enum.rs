use sea_orm_migration::prelude::{extension::postgres::Type, *};

use crate::user_scheme::{UserRole, UserStatus};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建用户角色 ENUM 类型
        manager
            .create_type(
                Type::create()
                    .as_enum(UserRole::Type)
                    .values(vec![
                        Alias::new("admin"),
                        Alias::new("user"),
                        Alias::new("moderator"),
                        Alias::new("editor"),
                        Alias::new("guest"),
                        Alias::new("developer"),
                        Alias::new("owner"),
                    ])
                    .to_owned(),
            )
            .await?;

        // 创建用户状态 ENUM 类型
        manager
            .create_type(
                Type::create()
                    .as_enum(UserStatus::Type)
                    .values(vec![
                        Alias::new("active"),
                        Alias::new("inactive"),
                        Alias::new("suspended"),
                        Alias::new("banned"),
                        Alias::new("pending"),
                        Alias::new("deleted"),
                    ])
                    .to_owned(),
            )
            .await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除 ENUM 类型
        manager
            .drop_type(Type::drop().name(UserStatus::Type).to_owned())
            .await?;

        manager
            .drop_type(Type::drop().name(UserRole::Type).to_owned())
            .await?;
        Ok(())
    }
}
