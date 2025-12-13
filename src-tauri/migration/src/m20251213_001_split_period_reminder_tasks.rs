// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20251213_001_split_period_reminder_tasks.rs
// Description:    拆分经期提醒任务为三个独立任务
// Create   Date:  2025-12-13
// -----------------------------------------------------------------------------

use crate::schema::SchedulerConfig;
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        use sea_orm_migration::sea_query::{OnConflict, Query};

        // 添加三个新的健康提醒任务配置
        let new_configs = vec![
            // 经期提醒 - 桌面端
            (
                "default-PeriodReminder-desktop",
                "PeriodReminder",
                "desktop",
                43200, // 12小时
                "经期提醒（桌面端，每12小时）",
            ),
            // 排卵期提醒 - 桌面端
            (
                "default-OvulationReminder-desktop",
                "OvulationReminder",
                "desktop",
                43200, // 12小时
                "排卵期提醒（桌面端，每12小时）",
            ),
            // PMS提醒 - 桌面端
            (
                "default-PmsReminder-desktop",
                "PmsReminder",
                "desktop",
                43200, // 12小时
                "PMS提醒（桌面端，每12小时）",
            ),
            // 经期提醒 - 移动端
            (
                "default-PeriodReminder-mobile",
                "PeriodReminder",
                "mobile",
                43200, // 12小时
                "经期提醒（移动端，每12小时）",
            ),
            // 排卵期提醒 - 移动端
            (
                "default-OvulationReminder-mobile",
                "OvulationReminder",
                "mobile",
                43200, // 12小时
                "排卵期提醒（移动端，每12小时）",
            ),
            // PMS提醒 - 移动端
            (
                "default-PmsReminder-mobile",
                "PmsReminder",
                "mobile",
                43200, // 12小时
                "PMS提醒（移动端，每12小时）",
            ),
        ];

        for (serial_num, task_type, platform, interval, description) in new_configs {
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
                            "2025-12-13T13:50:00+08:00".into(),
                            "2025-12-13T13:50:00+08:00".into(),
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

        // 删除旧的 PeriodReminderCheck 配置
        manager
            .exec_stmt(
                Query::delete()
                    .from_table(SchedulerConfig::Table)
                    .and_where(Expr::col(SchedulerConfig::TaskType).eq("PeriodReminderCheck"))
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        use sea_orm_migration::sea_query::Query;

        // 删除新添加的三个任务配置
        manager
            .exec_stmt(
                Query::delete()
                    .from_table(SchedulerConfig::Table)
                    .and_where(Expr::col(SchedulerConfig::TaskType).is_in([
                        "PeriodReminder",
                        "OvulationReminder",
                        "PmsReminder",
                    ]))
                    .to_owned(),
            )
            .await?;

        // 恢复旧的 PeriodReminderCheck 配置（可选）
        // 这里选择不恢复，因为向后回滚的情况很少

        Ok(())
    }
}
