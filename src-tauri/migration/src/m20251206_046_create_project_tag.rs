use crate::schema::{Project, ProjectTag, Tag};
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 project_tag 关联表
        manager
            .create_table(
                Table::create()
                    .table(ProjectTag::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(ProjectTag::ProjectSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(ProjectTag::TagSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(ColumnDef::new(ProjectTag::Orders).integer().null())
                    .col(
                        ColumnDef::new(ProjectTag::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(ProjectTag::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .primary_key(
                        Index::create()
                            .col(ProjectTag::ProjectSerialNum)
                            .col(ProjectTag::TagSerialNum),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(ProjectTag::Table, ProjectTag::ProjectSerialNum)
                            .to(Project::Table, Project::SerialNum)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .from(ProjectTag::Table, ProjectTag::TagSerialNum)
                            .to(Tag::Table, Tag::SerialNum)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引以提高查询性能
        manager
            .create_index(
                Index::create()
                    .if_not_exists()
                    .name("idx_project_tag_project")
                    .table(ProjectTag::Table)
                    .col(ProjectTag::ProjectSerialNum)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .if_not_exists()
                    .name("idx_project_tag_tag")
                    .table(ProjectTag::Table)
                    .col(ProjectTag::TagSerialNum)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(ProjectTag::Table).to_owned())
            .await
    }
}
