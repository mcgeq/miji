use sea_orm_migration::prelude::*;

use crate::schema::Categories;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
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
                    .index(
                        Index::create()
                            .name("idx_categories_name")
                            .table(Categories::Table)
                            .col(Categories::Name)
                            .unique(),
                    )
                    .to_owned(),
            )
            .await?;
        // 插入 CategorySchema 中的所有类别
        let categories = vec![
            "Food",
            "Transport",
            "Entertainment",
            "Utilities",
            "Shopping",
            "Salary",
            "Investment",
            "Transfer",
            "Education",
            "Healthcare",
            "Insurance",
            "Savings",
            "Gift",
            "Loan",
            "Business",
            "Travel",
            "Charity",
            "Subscription",
            "Pet",
            "Home",
            "Others",
        ];
        // 使用循环逐行插入数据，避免类型不匹配
        for name in categories {
            let insert = Query::insert()
                .into_table(Categories::Table)
                .columns([
                    Categories::Name,
                    Categories::CreatedAt,
                    Categories::UpdatedAt,
                ])
                .values_panic([
                    name.into(),
                    Expr::current_timestamp().into(),
                    Expr::current_timestamp().into(),
                ])
                .to_owned();
            manager.exec_stmt(insert).await?;
        }
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Categories::Table).to_owned())
            .await?;

        Ok(())
    }
}
