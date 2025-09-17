use crate::schema::SubCategories;
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 插入新的子分类
        let insert = Query::insert()
            .into_table(SubCategories::Table)
            .columns([
                SubCategories::Name,
                SubCategories::CategoryName,
                SubCategories::CreatedAt,
                SubCategories::UpdatedAt,
            ])
            .values_panic([
                "CreditCardRepayment".into(),
                "Transfer".into(),
                Expr::current_timestamp().into(),
                Expr::current_timestamp().into(),
            ])
            .to_owned();

        manager.exec_stmt(insert).await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚时删除该条数据
        let delete = Query::delete()
            .from_table(SubCategories::Table)
            .and_where(Expr::col(SubCategories::Name).eq("CreditCardRepayment"))
            .and_where(Expr::col(SubCategories::CategoryName).eq("Transfer"))
            .to_owned();

        manager.exec_stmt(delete).await?;
        Ok(())
    }
}
