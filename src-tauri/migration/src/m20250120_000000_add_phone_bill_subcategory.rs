use crate::schema::SubCategories;
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 插入话费子分类
        let insert = Query::insert()
            .into_table(SubCategories::Table)
            .columns([
                SubCategories::Name,
                SubCategories::CategoryName,
                SubCategories::CreatedAt,
                SubCategories::UpdatedAt,
            ])
            .values_panic([
                "PhoneBill".into(),
                "Utilities".into(),
                Expr::current_timestamp().into(),
                Expr::current_timestamp().into(),
            ])
            .to_owned();

        manager.exec_stmt(insert).await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚时删除话费子分类
        let delete = Query::delete()
            .from_table(SubCategories::Table)
            .and_where(Expr::col(SubCategories::Name).eq("PhoneBill"))
            .and_where(Expr::col(SubCategories::CategoryName).eq("Utilities"))
            .to_owned();

        manager.exec_stmt(delete).await?;
        Ok(())
    }
}
