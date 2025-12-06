use sea_orm_migration::prelude::*;

use crate::schema::{FamilyLedger, SplitRules};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 split_rules 表
        manager
            .create_table(
                Table::create()
                    .table(SplitRules::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(SplitRules::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::FamilyLedgerSerialNum)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(ColumnDef::new(SplitRules::Name).string_len(100).not_null())
                    .col(
                        ColumnDef::new(SplitRules::Description)
                            .string_len(500)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::RuleType)
                            .string_len(20)
                            .not_null()
                            .check(Expr::col(SplitRules::RuleType).is_in(vec![
                                "Equal",
                                "Percentage",
                                "FixedAmount",
                                "Weighted",
                                "Custom",
                            ])),
                    )
                    .col(ColumnDef::new(SplitRules::RuleConfig).json().not_null())
                    .col(
                        ColumnDef::new(SplitRules::ParticipantMembers)
                            .json()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::IsTemplate)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(SplitRules::IsDefault)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(SplitRules::Category).string_len(50).null())
                    .col(
                        ColumnDef::new(SplitRules::SubCategory)
                            .string_len(50)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::MinAmount)
                            .decimal_len(15, 2)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::MaxAmount)
                            .decimal_len(15, 2)
                            .null(),
                    )
                    .col(ColumnDef::new(SplitRules::Tags).json().null())
                    .col(
                        ColumnDef::new(SplitRules::Priority)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(SplitRules::IsActive)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(SplitRules::CreatedBy)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    // 外键约束
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_split_rules_family_ledger")
                            .from(SplitRules::Table, SplitRules::FamilyLedgerSerialNum)
                            .to(FamilyLedger::Table, FamilyLedger::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_split_rules_family_ledger")
                    .table(SplitRules::Table)
                    .col(SplitRules::FamilyLedgerSerialNum)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_split_rules_category")
                    .table(SplitRules::Table)
                    .col(SplitRules::Category)
                    .col(SplitRules::SubCategory)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_split_rules_template")
                    .table(SplitRules::Table)
                    .col(SplitRules::IsTemplate)
                    .col(SplitRules::IsActive)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_split_rules_template").to_owned())
            .await?;

        manager
            .drop_index(Index::drop().name("idx_split_rules_category").to_owned())
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_split_rules_family_ledger")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(SplitRules::Table).to_owned())
            .await?;

        Ok(())
    }
}
