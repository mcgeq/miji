use crate::schema::SubCategories;
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 插入房租/房屋租赁子分类并设置图标
        let insert = Query::insert()
            .into_table(SubCategories::Table)
            .columns([
                SubCategories::Name,
                SubCategories::CategoryName,
                SubCategories::Icon,
                SubCategories::CreatedAt,
                SubCategories::UpdatedAt,
            ])
            .values_panic([
                "PropertyRental".into(),
                "Utilities".into(),
                "🏡".into(),
                Expr::current_timestamp().into(),
                Expr::current_timestamp().into(),
            ])
            .to_owned();

        manager.exec_stmt(insert).await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let delete = Query::delete()
            .from_table(SubCategories::Table)
            .and_where(Expr::col(SubCategories::Name).eq("PropertyRental"))
            .and_where(Expr::col(SubCategories::CategoryName).eq("Utilities"))
            .to_owned();

        manager.exec_stmt(delete).await?;
        Ok(())
    }
}
