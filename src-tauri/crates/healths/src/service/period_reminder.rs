// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           period_reminder.rs
// Description:    经期提醒服务 - 使用统一通知服务
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use common::{
    utils::date::DateUtils, MijiResult, NotificationPriority,
    NotificationRequest, NotificationService, NotificationType,
};
use entity::period_records;
use sea_orm::{ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter};
use tauri::AppHandle;

/// 经期提醒服务
pub struct PeriodReminderService;

impl PeriodReminderService {
    pub fn new() -> Self {
        Self
    }

    /// 发送经期提醒通知
    ///
    /// # Arguments
    /// * `app` - Tauri 应用句柄
    /// * `db` - 数据库连接
    /// * `user_id` - 用户ID
    /// * `expected_date` - 预期日期
    pub async fn send_period_reminder(
        &self,
        app: &AppHandle,
        db: &DatabaseConnection,
        user_id: &str,
        expected_date: chrono::DateTime<chrono::FixedOffset>,
    ) -> MijiResult<()> {
        let notification_service = NotificationService::new();

        let days_until = (expected_date - DateUtils::local_now()).num_days();
        let body = if days_until <= 0 {
            "您的经期可能已经到来，请注意记录".to_string()
        } else if days_until == 1 {
            "您的经期预计明天到来，请做好准备".to_string()
        } else if days_until <= 3 {
            format!("您的经期预计在 {} 天后到来，请做好准备", days_until)
        } else {
            format!("您的经期预计在 {} 天后到来", days_until)
        };

        let request = NotificationRequest {
            notification_type: NotificationType::PeriodReminder,
            title: "🌸 经期提醒".to_string(),
            body,
            priority: NotificationPriority::Normal,
            reminder_id: None,
            user_id: user_id.to_string(),
            icon: Some("assets/period-icon.png".to_string()),
            actions: None,
            event_name: Some("period-reminder-fired".to_string()),
            event_payload: Some(serde_json::json!({
                "type": "period",
                "userId": user_id,
                "expectedDate": expected_date.timestamp(),
                "daysUntil": days_until,
            })),
        };

        notification_service.send(app, db, request).await
    }

    /// 发送排卵期提醒通知
    ///
    /// # Arguments
    /// * `app` - Tauri 应用句柄
    /// * `db` - 数据库连接
    /// * `user_id` - 用户ID
    /// * `ovulation_date` - 排卵日期
    pub async fn send_ovulation_reminder(
        &self,
        app: &AppHandle,
        db: &DatabaseConnection,
        user_id: &str,
        ovulation_date: chrono::DateTime<chrono::FixedOffset>,
    ) -> MijiResult<()> {
        let notification_service = NotificationService::new();

        let days_until = (ovulation_date - DateUtils::local_now()).num_days();
        let body = if days_until <= 0 {
            "今天是您的排卵期，备孕的好时机".to_string()
        } else if days_until == 1 {
            "明天是您的排卵期，如有备孕计划请注意".to_string()
        } else if days_until <= 3 {
            format!("您的排卵期预计在 {} 天后", days_until)
        } else {
            format!("距离排卵期还有 {} 天", days_until)
        };

        let request = NotificationRequest {
            notification_type: NotificationType::OvulationReminder,
            title: "💝 排卵期提醒".to_string(),
            body,
            priority: NotificationPriority::Normal,
            reminder_id: None,
            user_id: user_id.to_string(),
            icon: Some("assets/ovulation-icon.png".to_string()),
            actions: None,
            event_name: Some("ovulation-reminder-fired".to_string()),
            event_payload: Some(serde_json::json!({
                "type": "ovulation",
                "userId": user_id,
                "ovulationDate": ovulation_date.timestamp(),
                "daysUntil": days_until,
            })),
        };

        notification_service.send(app, db, request).await
    }

    /// 发送 PMS（经前综合征）提醒通知
    ///
    /// # Arguments
    /// * `app` - Tauri 应用句柄
    /// * `db` - 数据库连接
    /// * `user_id` - 用户ID
    /// * `period_date` - 预期经期日期
    pub async fn send_pms_reminder(
        &self,
        app: &AppHandle,
        db: &DatabaseConnection,
        user_id: &str,
        period_date: chrono::DateTime<chrono::FixedOffset>,
    ) -> MijiResult<()> {
        let notification_service = NotificationService::new();

        // PMS 通常在经期前 3-7 天出现
        let days_until = (period_date - DateUtils::local_now()).num_days();
        
        let body = if days_until >= 3 && days_until <= 7 {
            "经期将至，如有不适症状属于正常现象。建议保持心情愉悦，适度运动".to_string()
        } else {
            "注意调节情绪，保持良好的生活作息".to_string()
        };

        let request = NotificationRequest {
            notification_type: NotificationType::PmsReminder,
            title: "💆‍♀️ PMS 温馨提示".to_string(),
            body,
            priority: NotificationPriority::Low,
            reminder_id: None,
            user_id: user_id.to_string(),
            icon: Some("assets/pms-icon.png".to_string()),
            actions: None,
            event_name: Some("pms-reminder-fired".to_string()),
            event_payload: Some(serde_json::json!({
                "type": "pms",
                "userId": user_id,
                "periodDate": period_date.timestamp(),
                "daysUntil": days_until,
            })),
        };

        notification_service.send(app, db, request).await
    }

    /// 处理经期提醒 - 查询需要提醒的用户并发送通知
    ///
    /// # Arguments
    /// * `app` - Tauri 应用句柄
    /// * `db` - 数据库连接
    ///
    /// # Returns
    /// * `MijiResult<usize>` - 发送的提醒数量
    pub async fn process_period_reminders(
        &self,
        app: &AppHandle,
        db: &DatabaseConnection,
    ) -> MijiResult<usize> {
        let now = DateUtils::local_now();
        let mut sent_count = 0usize;

        // 查询最近的经期记录（用于预测）
        // 注意：这里简化实现，实际应该根据周期计算预测日期
        let recent_records = period_records::Entity::find()
            .filter(period_records::Column::StartDate.lte(now))
            .all(db)
            .await?;

        if recent_records.is_empty() {
            tracing::debug!("未找到需要处理的经期记录");
            return Ok(0);
        }

        // 简化实现：为每条记录发送提醒
        // 注意：period_records 表没有 user_id，这里使用系统用户
        // TODO: 实际应该：
        // 1. 关联用户表或在 period_records 中添加 user_id
        // 2. 根据历史周期计算预测日期
        // 3. 判断距离预测日期的天数
        // 4. 在合适的时间点发送提醒
        
        let system_user_id = "system"; // 临时使用系统用户ID
        
        for record in recent_records.iter().take(5) {
            // 假设平均周期 28 天
            let cycle_days = 28;
            let next_period_date = record.start_date + chrono::Duration::days(cycle_days);
            let days_until = (next_period_date - now).num_days();

            // 提前 3 天开始提醒
            if days_until >= 0 && days_until <= 3 {
                tracing::debug!(
                    "发送经期提醒: record={}, days_until={}",
                    record.serial_num,
                    days_until
                );

                // 发送经期提醒
                match self
                    .send_period_reminder(app, db, system_user_id, next_period_date)
                    .await
                {
                    Ok(_) => {
                        sent_count += 1;
                        tracing::info!("✅ 成功发送经期提醒: record={}", record.serial_num);
                    }
                    Err(e) => {
                        tracing::error!("❌ 发送经期提醒失败: record={}, error={}", record.serial_num, e);
                    }
                }
            }

            // 排卵期提醒（经期后第 14 天左右）
            let ovulation_date = record.start_date + chrono::Duration::days(14);
            let days_to_ovulation = (ovulation_date - now).num_days();

            if days_to_ovulation >= 0 && days_to_ovulation <= 2 {
                match self
                    .send_ovulation_reminder(app, db, system_user_id, ovulation_date)
                    .await
                {
                    Ok(_) => {
                        sent_count += 1;
                        tracing::info!("✅ 成功发送排卵期提醒: record={}", record.serial_num);
                    }
                    Err(e) => {
                        tracing::error!("❌ 发送排卵期提醒失败: record={}, error={}", record.serial_num, e);
                    }
                }
            }

            // PMS 提醒（经期前 3-7 天）
            if days_until >= 3 && days_until <= 7 {
                match self
                    .send_pms_reminder(app, db, system_user_id, next_period_date)
                    .await
                {
                    Ok(_) => {
                        sent_count += 1;
                        tracing::info!("✅ 成功发送 PMS 提醒: record={}", record.serial_num);
                    }
                    Err(e) => {
                        tracing::error!("❌ 发送 PMS 提醒失败: record={}, error={}", record.serial_num, e);
                    }
                }
            }
        }

        if sent_count > 0 {
            tracing::info!(
                "✅ 发送 {} 条健康提醒（使用统一通知服务）",
                sent_count
            );
        }

        Ok(sent_count)
    }
}

impl Default for PeriodReminderService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_period_reminder_service_creation() {
        let service = PeriodReminderService::new();
        assert!(std::mem::size_of_val(&service) == 0); // Zero-sized type
    }
}
