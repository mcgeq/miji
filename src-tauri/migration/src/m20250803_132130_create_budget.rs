use sea_orm_migration::prelude::*;

use crate::schema::{Account, Budget};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Budget::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Budget::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(Budget::AccountSerialNum)
                            .string_len(38)
                            .null(),
                    )
                    .col(ColumnDef::new(Budget::Name).string_len(20).not_null())
                    .col(ColumnDef::new(Budget::Description).string_len(400))
                    .col(
                        ColumnDef::new(Budget::Amount)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.0),
                    )
                    .col(ColumnDef::new(Budget::Currency).string_len(3).not_null())
                    .col(
                        ColumnDef::new(Budget::RepeatPeriod)
                            .json_binary()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::StartDate)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::EndDate)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::UsedAmount)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.0),
                    )
                    .col(
                        ColumnDef::new(Budget::IsActive)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(Budget::AlertEnabled)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(Budget::AlertThreshold).json_binary().null())
                    .col(ColumnDef::new(Budget::Color).string_len(7).null())
                    .col(
                        ColumnDef::new(Budget::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(Budget::CurrentPeriodUsed)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.0),
                    )
                    .col(ColumnDef::new(Budget::CurrentPeriodStart).date().not_null())
                    .col(
                        ColumnDef::new(Budget::LastResetAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Budget::BudgetType)
                            .string_len(20)
                            .not_null()
                            .default("Standard"),
                    )
                    .col(
                        ColumnDef::new(Budget::Progress)
                            .decimal_len(15, 2)
                            .not_null()
                            .default(0.0),
                    )
                    .col(ColumnDef::new(Budget::LinkedGoal).string().null())
                    .col(ColumnDef::new(Budget::Reminders).json_binary().null())
                    .col(
                        ColumnDef::new(Budget::Priority)
                            .tiny_integer()
                            .not_null()
                            .default(3),
                    )
                    .col(ColumnDef::new(Budget::Tags).json().null())
                    .col(
                        ColumnDef::new(Budget::AutoRollover)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(Budget::RolloverHistory).json_binary().null())
                    .col(ColumnDef::new(Budget::SharingSettings).json_binary().null())
                    .col(ColumnDef::new(Budget::Attachments).json_binary().null())
                    .col(
                        ColumnDef::new(Budget::BudgetScopeType)
                            .string_len(20)
                            .not_null()
                            .default("Category"),
                    )
                    .col(ColumnDef::new(Budget::AccountScope).json_binary().null())
                    .col(ColumnDef::new(Budget::CategoryScope).json_binary().null())
                    .col(ColumnDef::new(Budget::AdvancedRules).json_binary().null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_budget_account")
                            .from(Budget::Table, Budget::AccountSerialNum)
                            .to(Account::Table, Account::SerialNum)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;
        // 创建索引
        let indexes = vec![
            ("idx_budget_account", Budget::AccountSerialNum),
            ("idx_budget_type", Budget::BudgetType),
            ("idx_budget_active", Budget::IsActive),
            ("idx_budget_start_date", Budget::StartDate),
            ("idx_budget_scope_type", Budget::BudgetScopeType),
        ];
        for (name, column) in indexes {
            manager
                .create_index(
                    Index::create()
                        .name(name)
                        .table(Budget::Table)
                        .col(column)
                        .if_not_exists()
                        .to_owned(),
                )
                .await?;
        }
        // 为JSON字段创建GIN索引
        let json_indexes = vec![
            ("idx_budget_account_scope", Budget::AccountScope),
            ("idx_budget_category_scope", Budget::CategoryScope),
            ("idx_budget_advanced_rules", Budget::AdvancedRules),
        ];

        for (name, column) in json_indexes {
            manager
                .create_index(
                    Index::create()
                        .name(name)
                        .table(Budget::Table)
                        .col(column)
                        .index_type(IndexType::Custom(SeaRc::new(GinIndex)))
                        .if_not_exists()
                        .to_owned(),
                )
                .await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let indexes = vec![
            "idx_budget_account",
            "idx_budget_type",
            "idx_budget_active",
            "idx_budget_start_date",
            "idx_budget_scope_type",
            "idx_budget_account_scope",
            "idx_budget_category_scope",
            "idx_budget_advanced_rules",
        ];

        for name in indexes {
            manager
                .drop_index(Index::drop().name(name).to_owned())
                .await?;
        }

        // 删除表
        manager
            .drop_table(Table::drop().table(Budget::Table).to_owned())
            .await?;
        Ok(())
    }
}

#[derive(Debug, Clone, Copy)]
pub struct GinIndex;

impl Iden for GinIndex {
    fn unquoted(&self, s: &mut dyn std::fmt::Write) {
        write!(s, "gin").unwrap();
    }
}
