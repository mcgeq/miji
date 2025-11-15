use sea_orm_migration::prelude::*;

use crate::schema::FamilyLedger;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 检查并添加结算日字段
        if !manager.has_column("family_ledger", "settlement_day").await? {
            manager
                .alter_table(
                    Table::alter()
                        .table(FamilyLedger::Table)
                        .add_column(
                            ColumnDef::new(FamilyLedger::SettlementDay)
                                .integer()
                                .not_null()
                                .default(1)
                                .check(
                                    Expr::col(FamilyLedger::SettlementDay)
                                        .between(1, 31),
                                ),
                        )
                        .to_owned(),
                )
                .await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(FamilyLedger::Table)
                    .drop_column(FamilyLedger::SettlementDay)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}
