use sea_orm_migration::prelude::*;

use crate::schema::PeriodRecords;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(PeriodRecords::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(PeriodRecords::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(PeriodRecords::Notes)
                            .text()
                            .check(Expr::cust("LENGTH(notes) <= 1000")),
                    )
                    .col(ColumnDef::new(PeriodRecords::StartDate).string().not_null())
                    .col(ColumnDef::new(PeriodRecords::EndDate).string().not_null())
                    .col(ColumnDef::new(PeriodRecords::CreatedAt).string().not_null())
                    .col(ColumnDef::new(PeriodRecords::UpdatedAt).string())
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(PeriodRecords::Table).to_owned())
            .await?;

        Ok(())
    }
}
