use sea_orm_migration::prelude::*;

use crate::schema::{FamilyLedger, SplitRules};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
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
                    .col(
                        ColumnDef::new(SplitRules::Name)
                            .string_len(100)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::Description)
                            .string_len(500)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(SplitRules::RuleType)
                            .string_len(20)
                            .not_null()
                            .check(
                                Expr::col(SplitRules::RuleType)
                                    .is_in(vec!["Equal", "Percentage", "FixedAmount", "Weighted", "Custom"]),
                            ),
                    )
                    .col(
                        ColumnDef::new(SplitRules::RuleConfig)
                            .json()
                            .not_null(),
                    )
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
                    .col(
                        ColumnDef::new(SplitRules::Category)
                            .string_len(50)
                            .null(),
                    )
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
                    .col(
                        ColumnDef::new(SplitRules::Tags)
                            .json()
                            .null(),
                    )
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
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_split_rules_family_ledger")
                            .from(SplitRules::Table, SplitRules::FamilyLedgerSerialNum)
                            .to(FamilyLedger::Table, FamilyLedger::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .index(
                        Index::create()
                            .name("idx_split_rules_family_ledger")
                            .table(SplitRules::Table)
                            .col(SplitRules::FamilyLedgerSerialNum),
                    )
                    .index(
                        Index::create()
                            .name("idx_split_rules_category")
                            .table(SplitRules::Table)
                            .col(SplitRules::Category)
                            .col(SplitRules::SubCategory),
                    )
                    .index(
                        Index::create()
                            .name("idx_split_rules_template")
                            .table(SplitRules::Table)
                            .col(SplitRules::IsTemplate)
                            .col(SplitRules::IsActive),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(SplitRules::Table).to_owned())
            .await?;

        Ok(())
    }
}
