use sea_orm_migration::prelude::*;

use crate::schema::Project;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Project::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Project::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Project::Name).string().not_null())
                    .col(
                        ColumnDef::new(Project::Description)
                            .text()
                            .check(Expr::cust("LENGTH(description) <= 1000")),
                    )
                    .col(
                        ColumnDef::new(Project::OwnerId)
                            .string()
                            .check(Expr::cust("LENGTH(owner_id) <= 38")),
                    )
                    .col(ColumnDef::new(Project::Color).string())
                    .col(
                        ColumnDef::new(Project::IsArchived)
                            .integer()
                            .not_null()
                            .default(0)
                            .check(Expr::col(Project::IsArchived).is_in(vec![0, 1])),
                    )
                    .col(ColumnDef::new(Project::CreatedAt).string().not_null())
                    .col(ColumnDef::new(Project::UpdatedAt).string())
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_project_name")
                    .table(Project::Table)
                    .col(Project::Name)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_project_owner")
                    .table(Project::Table)
                    .col(Project::OwnerId)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_project_name").to_owned())
            .await?;

        manager
            .drop_index(Index::drop().name("idx_project_owner").to_owned())
            .await?;

        manager
            .drop_table(Table::drop().table(Project::Table).to_owned())
            .await?;

        Ok(())
    }
}
