use crate::schema::{Currency, FamilyLedger};
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // SQLite 不支持直接 ALTER COLUMN 修改类型
        // 需要使用重建表的方式
        // 由于还没有数据，我们可以直接删除旧表并创建新表

        // 1. 删除旧表
        manager
            .drop_table(
                Table::drop()
                    .table(FamilyLedger::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await?;

        // 2. 创建新表（直接使用正式表名，包含外键）
        manager
            .create_table(
                Table::create()
                    .table(FamilyLedger::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FamilyLedger::SerialNum)
                            .string()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(FamilyLedger::Name).string())
                    .col(
                        ColumnDef::new(FamilyLedger::Description)
                            .string()
                            .not_null()
                            .default(""),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::BaseCurrency)
                            .string()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Members)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Accounts)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Transactions)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::Budgets)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::AuditLogs)
                            .string()
                            .not_null()
                            .default("[]"),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::LedgerType)
                            .string()
                            .not_null()
                            .default("Family"),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::SettlementCycle)
                            .string()
                            .not_null()
                            .default("Monthly"),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::SettlementDay)
                            .integer()
                            .not_null()
                            .default(1),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::AutoSettlement)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(FamilyLedger::DefaultSplitRule).json())
                    .col(ColumnDef::new(FamilyLedger::LastSettlementAt).timestamp_with_time_zone())
                    .col(ColumnDef::new(FamilyLedger::NextSettlementAt).timestamp_with_time_zone())
                    .col(
                        ColumnDef::new(FamilyLedger::Status)
                            .string()
                            .not_null()
                            .default("Active"),
                    )
                    .col(
                        ColumnDef::new(FamilyLedger::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(ColumnDef::new(FamilyLedger::UpdatedAt).timestamp_with_time_zone())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_currency")
                            .from(FamilyLedger::Table, FamilyLedger::BaseCurrency)
                            .to(Currency::Table, Currency::Code)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚：将整数字段改回 JSON 字符串
        // 由于没有数据，直接删除并重建旧表结构

        // 1. 删除当前表
        manager
            .drop_table(
                Table::drop()
                    .table(FamilyLedger::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await?;

        // 2. 创建旧表结构（使用 JSON 字符串字段，包含外键）
        manager
            .create_table(
                Table::create()
                    .table(FamilyLedgerOld::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FamilyLedgerOld::SerialNum)
                            .string()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(FamilyLedgerOld::Name).string())
                    .col(
                        ColumnDef::new(FamilyLedgerOld::Description)
                            .string()
                            .not_null()
                            .default(""),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerOld::BaseCurrency)
                            .string()
                            .not_null(),
                    )
                    .col(ColumnDef::new(FamilyLedgerOld::Members).string())
                    .col(ColumnDef::new(FamilyLedgerOld::Accounts).string())
                    .col(ColumnDef::new(FamilyLedgerOld::Transactions).string())
                    .col(ColumnDef::new(FamilyLedgerOld::Budgets).string())
                    .col(
                        ColumnDef::new(FamilyLedgerOld::AuditLogs)
                            .string()
                            .not_null()
                            .default("[]"),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerOld::LedgerType)
                            .string()
                            .not_null()
                            .default("Family"),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerOld::SettlementCycle)
                            .string()
                            .not_null()
                            .default("Monthly"),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerOld::SettlementDay)
                            .integer()
                            .not_null()
                            .default(1),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerOld::AutoSettlement)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(FamilyLedgerOld::DefaultSplitRule).json())
                    .col(
                        ColumnDef::new(FamilyLedgerOld::LastSettlementAt)
                            .timestamp_with_time_zone(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerOld::NextSettlementAt)
                            .timestamp_with_time_zone(),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerOld::Status)
                            .string()
                            .not_null()
                            .default("Active"),
                    )
                    .col(
                        ColumnDef::new(FamilyLedgerOld::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(ColumnDef::new(FamilyLedgerOld::UpdatedAt).timestamp_with_time_zone())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_family_ledger_currency")
                            .from(FamilyLedgerOld::Table, FamilyLedgerOld::BaseCurrency)
                            .to(Currency::Table, Currency::Code)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 3. 重命名为正式表名
        manager
            .rename_table(
                Table::rename()
                    .table(FamilyLedgerOld::Table, FamilyLedger::Table)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}

// 旧表结构定义（用于回滚）
#[derive(DeriveIden)]
enum FamilyLedgerOld {
    Table,
    SerialNum,
    Name,
    Description,
    BaseCurrency,
    Members,
    Accounts,
    Transactions,
    Budgets,
    AuditLogs,
    LedgerType,
    SettlementCycle,
    SettlementDay,
    AutoSettlement,
    DefaultSplitRule,
    LastSettlementAt,
    NextSettlementAt,
    Status,
    CreatedAt,
    UpdatedAt,
}
