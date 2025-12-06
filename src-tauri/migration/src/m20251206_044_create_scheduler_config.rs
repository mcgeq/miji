// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20251206_044_create_scheduler_config.rs
// Description:    创建调度器配置表
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 scheduler_config 表
        manager
            .create_table(
                Table::create()
                    .table(SchedulerConfig::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(SchedulerConfig::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key()
                            .comment("主键ID"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::UserSerialNum)
                            .string_len(38)
                            .null()
                            .comment("用户ID，NULL表示全局配置"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::TaskType)
                            .string()
                            .not_null()
                            .comment("任务类型"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::Enabled)
                            .boolean()
                            .not_null()
                            .default(true)
                            .comment("是否启用"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::IntervalSeconds)
                            .integer()
                            .not_null()
                            .comment("执行间隔（秒）"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::MaxRetryCount)
                            .integer()
                            .default(3)
                            .comment("最大重试次数"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::RetryDelaySeconds)
                            .integer()
                            .default(60)
                            .comment("重试延迟（秒）"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::Platform)
                            .string()
                            .null()
                            .comment("平台限定：desktop, mobile, android, ios"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::BatteryThreshold)
                            .integer()
                            .null()
                            .comment("电量阈值（移动端）"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::NetworkRequired)
                            .boolean()
                            .not_null()
                            .default(false)
                            .comment("是否需要网络"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::WifiOnly)
                            .boolean()
                            .not_null()
                            .default(false)
                            .comment("仅Wi-Fi"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::ActiveHoursStart)
                            .time()
                            .null()
                            .comment("活动时段开始"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::ActiveHoursEnd)
                            .time()
                            .null()
                            .comment("活动时段结束"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::Priority)
                            .integer()
                            .not_null()
                            .default(5)
                            .comment("优先级 1-10"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::Description)
                            .text()
                            .null()
                            .comment("配置描述"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::IsDefault)
                            .boolean()
                            .not_null()
                            .default(false)
                            .comment("是否为默认配置"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .comment("创建时间"),
                    )
                    .col(
                        ColumnDef::new(SchedulerConfig::UpdatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .comment("更新时间"),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建唯一索引：每个用户+任务类型+平台只能有一条配置
        manager
            .create_index(
                Index::create()
                    .name("idx_scheduler_config_unique")
                    .table(SchedulerConfig::Table)
                    .col(SchedulerConfig::UserSerialNum)
                    .col(SchedulerConfig::TaskType)
                    .col(SchedulerConfig::Platform)
                    .unique()
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建任务类型索引
        manager
            .create_index(
                Index::create()
                    .name("idx_scheduler_config_task")
                    .table(SchedulerConfig::Table)
                    .col(SchedulerConfig::TaskType)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建用户索引
        manager
            .create_index(
                Index::create()
                    .name("idx_scheduler_config_user")
                    .table(SchedulerConfig::Table)
                    .col(SchedulerConfig::UserSerialNum)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建启用状态索引
        manager
            .create_index(
                Index::create()
                    .name("idx_scheduler_config_enabled")
                    .table(SchedulerConfig::Table)
                    .col(SchedulerConfig::Enabled)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 创建平台索引
        manager
            .create_index(
                Index::create()
                    .name("idx_scheduler_config_platform")
                    .table(SchedulerConfig::Table)
                    .col(SchedulerConfig::Platform)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        // 插入默认配置
        self.insert_default_configs(manager).await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除索引
        manager
            .drop_index(
                Index::drop()
                    .name("idx_scheduler_config_platform")
                    .table(SchedulerConfig::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_scheduler_config_enabled")
                    .table(SchedulerConfig::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_scheduler_config_user")
                    .table(SchedulerConfig::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_scheduler_config_task")
                    .table(SchedulerConfig::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("idx_scheduler_config_unique")
                    .table(SchedulerConfig::Table)
                    .to_owned(),
            )
            .await?;

        // 删除表
        manager
            .drop_table(Table::drop().table(SchedulerConfig::Table).to_owned())
            .await
    }
}

impl Migration {
    /// 插入默认配置数据
    async fn insert_default_configs(&self, manager: &SchemaManager<'_>) -> Result<(), DbErr> {
        use sea_orm_migration::sea_query::{OnConflict, Query};
        let default_configs = vec![
            // 桌面端配置
            (
                "default-TransactionProcess-desktop",
                "TransactionProcess",
                "desktop",
                7200,
                "交易处理任务（桌面端，每2小时）",
            ),
            (
                "default-TodoAutoCreate-desktop",
                "TodoAutoCreate",
                "desktop",
                7200,
                "待办自动创建（桌面端，每2小时）",
            ),
            (
                "default-TodoReminderCheck-desktop",
                "TodoReminderCheck",
                "desktop",
                60,
                "待办提醒检查（桌面端，每1分钟）",
            ),
            (
                "default-BillReminderCheck-desktop",
                "BillReminderCheck",
                "desktop",
                60,
                "账单提醒检查（桌面端，每1分钟）",
            ),
            (
                "default-PeriodReminderCheck-desktop",
                "PeriodReminderCheck",
                "desktop",
                86400,
                "经期提醒检查（桌面端，每天）",
            ),
            (
                "default-BudgetAutoCreate-desktop",
                "BudgetAutoCreate",
                "desktop",
                7200,
                "预算自动创建（桌面端，每2小时）",
            ),
            // 移动端配置
            (
                "default-TransactionProcess-mobile",
                "TransactionProcess",
                "mobile",
                7200,
                "交易处理任务（移动端，每2小时）",
            ),
            (
                "default-TodoAutoCreate-mobile",
                "TodoAutoCreate",
                "mobile",
                7200,
                "待办自动创建（移动端，每2小时）",
            ),
            (
                "default-TodoReminderCheck-mobile",
                "TodoReminderCheck",
                "mobile",
                300,
                "待办提醒检查（移动端，每5分钟）",
            ),
            (
                "default-BillReminderCheck-mobile",
                "BillReminderCheck",
                "mobile",
                300,
                "账单提醒检查（移动端，每5分钟）",
            ),
            (
                "default-PeriodReminderCheck-mobile",
                "PeriodReminderCheck",
                "mobile",
                86400,
                "经期提醒检查（移动端，每天）",
            ),
            (
                "default-BudgetAutoCreate-mobile",
                "BudgetAutoCreate",
                "mobile",
                7200,
                "预算自动创建（移动端，每2小时）",
            ),
        ];

        for (serial_num, task_type, platform, interval, description) in default_configs {
            manager
                .exec_stmt(
                    Query::insert()
                        .into_table(SchedulerConfig::Table)
                        .columns([
                            SchedulerConfig::SerialNum,
                            SchedulerConfig::TaskType,
                            SchedulerConfig::Platform,
                            SchedulerConfig::Enabled,
                            SchedulerConfig::IntervalSeconds,
                            SchedulerConfig::MaxRetryCount,
                            SchedulerConfig::RetryDelaySeconds,
                            SchedulerConfig::BatteryThreshold,
                            SchedulerConfig::NetworkRequired,
                            SchedulerConfig::WifiOnly,
                            SchedulerConfig::Priority,
                            SchedulerConfig::Description,
                            SchedulerConfig::IsDefault,
                            SchedulerConfig::CreatedAt,
                            SchedulerConfig::UpdatedAt,
                        ])
                        .values_panic([
                            serial_num.into(),
                            task_type.into(),
                            platform.into(),
                            true.into(),
                            interval.into(),
                            3.into(),
                            60.into(),
                            20.into(), // 电量阈值20%
                            false.into(),
                            false.into(),
                            5.into(),
                            description.into(),
                            true.into(),
                            "2025-12-06T12:00:00+08:00".into(),
                            "2025-12-06T12:00:00+08:00".into(),
                        ])
                        .on_conflict(
                            OnConflict::column(SchedulerConfig::SerialNum)
                                .do_nothing()
                                .to_owned(),
                        )
                        .to_owned(),
                )
                .await?;
        }

        Ok(())
    }
}

/// 调度器配置表定义
#[derive(DeriveIden)]
enum SchedulerConfig {
    Table,
    SerialNum,
    UserSerialNum,
    TaskType,
    Enabled,
    IntervalSeconds,
    MaxRetryCount,
    RetryDelaySeconds,
    Platform,
    BatteryThreshold,
    NetworkRequired,
    WifiOnly,
    ActiveHoursStart,
    ActiveHoursEnd,
    Priority,
    Description,
    IsDefault,
    CreatedAt,
    UpdatedAt,
}
