// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           notification_service.rs
// Description:    统一的跨模块通知服务
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use crate::{AppError, BusinessCode, MijiResult};
use chrono::{Datelike, Local};
use sea_orm::DatabaseConnection;
use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter};

/// 通知类型枚举
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "PascalCase")]
pub enum NotificationType {
    /// 待办提醒
    TodoReminder,
    /// 账单提醒
    BillReminder,
    /// 经期提醒
    PeriodReminder,
    /// 排卵期提醒
    OvulationReminder,
    /// PMS 提醒
    PmsReminder,
    /// 系统警报
    SystemAlert,
    /// 自定义类型
    Custom(String),
}

impl NotificationType {
    /// 转换为字符串
    pub fn as_str(&self) -> &str {
        match self {
            Self::TodoReminder => "TodoReminder",
            Self::BillReminder => "BillReminder",
            Self::PeriodReminder => "PeriodReminder",
            Self::OvulationReminder => "OvulationReminder",
            Self::PmsReminder => "PmsReminder",
            Self::SystemAlert => "SystemAlert",
            Self::Custom(s) => s.as_str(),
        }
    }
}

/// 通知优先级
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "PascalCase")]
pub enum NotificationPriority {
    /// 低优先级（普通通知）
    Low,
    /// 正常优先级
    Normal,
    /// 高优先级（重要通知）
    High,
    /// 紧急通知（忽略免打扰设置）
    Urgent,
}

impl NotificationPriority {
    /// 转换为字符串
    pub fn as_str(&self) -> &str {
        match self {
            Self::Low => "Low",
            Self::Normal => "Normal",
            Self::High => "High",
            Self::Urgent => "Urgent",
        }
    }
}

/// 通知操作按钮
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationAction {
    /// 操作ID
    pub id: String,
    /// 操作标题
    pub title: String,
}

/// 通知请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationRequest {
    /// 通知类型
    pub notification_type: NotificationType,

    /// 标题
    pub title: String,

    /// 内容
    pub body: String,

    /// 优先级
    #[serde(default = "default_priority")]
    pub priority: NotificationPriority,

    /// 关联的提醒记录ID（用于日志）
    pub reminder_id: Option<String>,

    /// 用户ID
    pub user_id: String,

    /// 自定义图标（可选）
    pub icon: Option<String>,

    /// 操作按钮（可选）
    pub actions: Option<Vec<NotificationAction>>,

    /// 前端事件名称（可选）
    pub event_name: Option<String>,

    /// 前端事件数据（可选）
    pub event_payload: Option<serde_json::Value>,
}

fn default_priority() -> NotificationPriority {
    NotificationPriority::Normal
}

/// 统一通知服务
pub struct NotificationService {
    settings_checker: SettingsChecker,
    log_recorder: LogRecorder,
    #[allow(dead_code)] // 移动端权限管理，桌面端不使用
    permission_manager: PermissionManager,
}

impl NotificationService {
    /// 创建新的通知服务实例
    pub fn new() -> Self {
        Self {
            settings_checker: SettingsChecker::new(),
            log_recorder: LogRecorder::new(),
            permission_manager: PermissionManager::new(),
        }
    }

    /// 发送通知（主入口）
    ///
    /// # Arguments
    /// * `app` - Tauri 应用句柄
    /// * `db` - 数据库连接
    /// * `request` - 通知请求
    ///
    /// # Returns
    /// * `MijiResult<()>` - 成功或错误
    pub async fn send(
        &self,
        app: &AppHandle,
        db: &DatabaseConnection,
        request: NotificationRequest,
    ) -> MijiResult<()> {
        tracing::debug!(
            "发送通知请求: type={}, title={}",
            request.notification_type.as_str(),
            request.title
        );

        // 1. 检查权限（移动端）
        #[cfg(any(target_os = "android", target_os = "ios"))]
        {
            if !self.permission_manager.check_permission(app).await? {
                tracing::warn!("通知权限未授予，尝试请求权限");
                self.permission_manager.request_permission(app).await?;
            }
        }

        // 2. 检查用户设置
        if !self.should_send_notification(db, &request).await? {
            tracing::debug!(
                "通知被用户设置阻止: type={}, user={}",
                request.notification_type.as_str(),
                request.user_id
            );
            return Ok(());
        }

        // 3. 创建日志记录
        let log_id = self.log_recorder.create_pending_log(db, &request).await?;

        // 4. 发送通知
        match self.send_platform_notification(app, &request).await {
            Ok(_) => {
                tracing::info!("通知发送成功: {}", request.title);

                // 更新日志为成功
                self.log_recorder.mark_success(db, &log_id).await?;

                // 发送前端事件
                if let Some(event_name) = &request.event_name {
                    let payload = request
                        .event_payload
                        .clone()
                        .unwrap_or_else(|| serde_json::json!({}));
                    let _ = app.emit(event_name, payload);
                }

                Ok(())
            }
            Err(e) => {
                tracing::error!("通知发送失败: {} - {}", request.title, e);

                // 更新日志为失败
                self.log_recorder
                    .mark_failed(db, &log_id, &e.to_string())
                    .await?;

                Err(e)
            }
        }
    }

    /// 检查是否应该发送通知
    async fn should_send_notification(
        &self,
        db: &DatabaseConnection,
        request: &NotificationRequest,
    ) -> MijiResult<bool> {
        // 紧急通知总是发送（忽略所有设置）
        if request.priority == NotificationPriority::Urgent {
            tracing::debug!("紧急通知，忽略用户设置");
            return Ok(true);
        }

        // 检查用户设置
        self.settings_checker
            .check(db, &request.user_id, &request.notification_type)
            .await
    }

    /// 发送平台通知
    async fn send_platform_notification(
        &self,
        app: &AppHandle,
        request: &NotificationRequest,
    ) -> MijiResult<()> {
        use tauri_plugin_notification::NotificationExt;

        let mut builder = app.notification().builder();

        // 设置标题和内容
        builder = builder.title(&request.title).body(&request.body);

        // 添加图标
        if let Some(icon) = &request.icon {
            builder = builder.icon(icon);
        }

        // 注意：操作按钮支持取决于 tauri-plugin-notification 版本
        // 当前版本可能不支持，暂时注释
        // #[cfg(not(any(target_os = "android", target_os = "ios")))]
        // if let Some(actions) = &request.actions {
        //     for action in actions {
        //         builder = builder.action(&action.title);
        //     }
        // }

        // Android 特定配置
        #[cfg(target_os = "android")]
        {
            builder = self.configure_android_notification(builder, request);
        }

        // iOS 特定配置
        #[cfg(target_os = "ios")]
        {
            builder = self.configure_ios_notification(builder, request);
        }

        // 发送通知
        builder
            .show()
            .map_err(|e| AppError::simple(BusinessCode::SystemError, e.to_string()))
    }

    /// 配置 Android 通知
    #[cfg(target_os = "android")]
    fn configure_android_notification(
        &self,
        mut builder: tauri_plugin_notification::NotificationBuilder,
        request: &NotificationRequest,
    ) -> tauri_plugin_notification::NotificationBuilder {
        // 设置通知渠道
        let channel = match request.notification_type {
            NotificationType::TodoReminder => "todo_reminders",
            NotificationType::BillReminder => "bill_reminders",
            NotificationType::PeriodReminder
            | NotificationType::OvulationReminder
            | NotificationType::PmsReminder => "health_reminders",
            NotificationType::SystemAlert => "system_alerts",
            NotificationType::Custom(_) => "custom_notifications",
        };
        builder = builder.channel(channel);

        // 设置优先级
        let priority = match request.priority {
            NotificationPriority::Low => "low",
            NotificationPriority::Normal => "default",
            NotificationPriority::High => "high",
            NotificationPriority::Urgent => "max",
        };
        builder = builder.priority(priority);

        builder
    }

    /// 配置 iOS 通知
    #[cfg(target_os = "ios")]
    fn configure_ios_notification(
        &self,
        mut builder: tauri_plugin_notification::NotificationBuilder,
        request: &NotificationRequest,
    ) -> tauri_plugin_notification::NotificationBuilder {
        // 设置声音
        builder = builder.sound("default");

        // 高优先级通知设置角标
        if matches!(
            request.priority,
            NotificationPriority::High | NotificationPriority::Urgent
        ) {
            builder = builder.badge(1);
        }

        builder
    }
}

impl Default for NotificationService {
    fn default() -> Self {
        Self::new()
    }
}

// ============================================================================
// 设置检查器
// ============================================================================

/// 用户通知设置检查器
pub struct SettingsChecker;

impl SettingsChecker {
    pub fn new() -> Self {
        Self
    }

    /// 检查用户通知设置
    ///
    /// # Arguments
    /// * `db` - 数据库连接
    /// * `user_id` - 用户ID
    /// * `notification_type` - 通知类型
    ///
    /// # Returns
    /// * `MijiResult<bool>` - 是否允许发送通知
    pub async fn check(
        &self,
        db: &DatabaseConnection,
        user_id: &str,
        notification_type: &NotificationType,
    ) -> MijiResult<bool> {
        use ::entity::notification_settings;
        use sea_orm::*;

        // 查询用户设置
        let settings = notification_settings::Entity::find()
            .filter(notification_settings::Column::UserId.eq(user_id))
            .filter(notification_settings::Column::NotificationType.eq(notification_type.as_str()))
            .one(db)
            .await?;

        if let Some(s) = settings {
            // 检查是否启用
            if !s.enabled {
                tracing::debug!("通知类型已禁用: {}", notification_type.as_str());
                return Ok(false);
            }

            // 检查免打扰时段
            if let (Some(start), Some(end)) = (s.quiet_hours_start, s.quiet_hours_end) {
                let now = Local::now().naive_local().time();
                if now >= start && now <= end {
                    tracing::debug!("处于免打扰时段: {:?} - {:?}", start, end);
                    return Ok(false);
                }
            }

            // 检查免打扰日期
            if let Some(days_json) = s.quiet_days {
                if let Ok(days) = serde_json::from_value::<Vec<String>>(days_json) {
                    let today = Local::now().weekday().number_from_monday();
                    if days.contains(&today.to_string()) {
                        tracing::debug!("处于免打扰日期: 星期{}", today);
                        return Ok(false);
                    }
                }
            }
        } else {
            // 没有设置记录，默认允许发送
            tracing::debug!("未找到用户设置，默认允许发送");
        }

        Ok(true)
    }
}

impl Default for SettingsChecker {
    fn default() -> Self {
        Self::new()
    }
}

// ============================================================================
// 日志记录器
// ============================================================================

/// 通知日志记录器
pub struct LogRecorder;

impl LogRecorder {
    pub fn new() -> Self {
        Self
    }

    /// 创建待发送日志
    ///
    /// # Arguments
    /// * `db` - 数据库连接
    /// * `request` - 通知请求
    ///
    /// # Returns
    /// * `MijiResult<String>` - 日志ID
    pub async fn create_pending_log(
        &self,
        db: &DatabaseConnection,
        request: &NotificationRequest,
    ) -> MijiResult<String> {
        use crate::utils::{date::DateUtils, uuid::McgUuid};
        use ::entity::notification_logs;
        use sea_orm::*;

        let log_id = McgUuid::uuid(38);
        let log = notification_logs::ActiveModel {
            serial_num: Set(log_id.clone()),
            reminder_serial_num: Set(request.reminder_id.clone().unwrap_or_default()),
            notification_type: Set(request.notification_type.as_str().to_string()),
            priority: Set(request.priority.as_str().to_string()),
            status: Set("Pending".to_string()),
            sent_at: Set(None),
            error_message: Set(None),
            retry_count: Set(0),
            last_retry_at: Set(None),
            created_at: Set(DateUtils::local_now()),
            updated_at: Set(None),
        };

        log.insert(db).await?;
        tracing::debug!("创建通知日志: {}", log_id);
        Ok(log_id)
    }

    /// 标记为成功
    ///
    /// # Arguments
    /// * `db` - 数据库连接
    /// * `log_id` - 日志ID
    pub async fn mark_success(&self, db: &DatabaseConnection, log_id: &str) -> MijiResult<()> {
        use crate::utils::date::DateUtils;
        use ::entity::notification_logs;
        use sea_orm::*;

        let log = notification_logs::Entity::find_by_id(log_id)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "通知日志不存在"))?;

        let mut active: notification_logs::ActiveModel = log.into();
        active.status = Set("Sent".to_string());
        active.sent_at = Set(Some(DateUtils::local_now()));
        active.updated_at = Set(Some(DateUtils::local_now()));
        active.update(db).await?;

        tracing::debug!("更新通知日志为成功: {}", log_id);
        Ok(())
    }

    /// 标记为失败
    ///
    /// # Arguments
    /// * `db` - 数据库连接
    /// * `log_id` - 日志ID
    /// * `error` - 错误信息
    pub async fn mark_failed(
        &self,
        db: &DatabaseConnection,
        log_id: &str,
        error: &str,
    ) -> MijiResult<()> {
        use crate::utils::date::DateUtils;
        use ::entity::notification_logs;
        use sea_orm::*;

        let log = notification_logs::Entity::find_by_id(log_id)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "通知日志不存在"))?;

        let retry_count = log.retry_count;
        let mut active: notification_logs::ActiveModel = log.into();
        active.status = Set("Failed".to_string());
        active.error_message = Set(Some(error.to_string()));
        active.retry_count = Set(retry_count + 1);
        active.last_retry_at = Set(Some(DateUtils::local_now()));
        active.updated_at = Set(Some(DateUtils::local_now()));
        active.update(db).await?;

        tracing::warn!("更新通知日志为失败: {} - {}", log_id, error);
        Ok(())
    }
}

impl Default for LogRecorder {
    fn default() -> Self {
        Self::new()
    }
}

// ============================================================================
// 权限管理器
// ============================================================================

/// 通知权限管理器（主要用于移动端）
pub struct PermissionManager;

impl PermissionManager {
    pub fn new() -> Self {
        Self
    }

    /// 检查通知权限
    ///
    /// # Arguments
    /// * `app` - Tauri 应用句柄
    ///
    /// # Returns
    /// * `MijiResult<bool>` - 是否有权限
    pub async fn check_permission(&self, _app: &AppHandle) -> MijiResult<bool> {
        #[cfg(any(target_os = "android", target_os = "ios"))]
        {
            // TODO: 实现实际的权限检查
            // 这需要使用 Tauri 的权限 API 或原生插件
            tracing::debug!("检查通知权限（移动端）");
            Ok(true) // 暂时假设有权限
        }

        #[cfg(not(any(target_os = "android", target_os = "ios")))]
        Ok(true) // 桌面端默认有权限
    }

    /// 请求通知权限
    ///
    /// # Arguments
    /// * `app` - Tauri 应用句柄
    pub async fn request_permission(&self, _app: &AppHandle) -> MijiResult<()> {
        #[cfg(any(target_os = "android", target_os = "ios"))]
        {
            // TODO: 实现实际的权限请求
            // 这需要使用 Tauri 的权限 API 或原生插件
            tracing::info!("请求通知权限（移动端）");
        }

        Ok(())
    }
}

impl Default for PermissionManager {
    fn default() -> Self {
        Self::new()
    }
}

// ============================================================================
// 统计服务
// ============================================================================

/// 通知统计服务
pub struct StatisticsService;

impl StatisticsService {
    pub fn new() -> Self {
        Self
    }

    /// 获取通知统计信息
    ///
    /// # Arguments
    /// * `db` - 数据库连接
    /// * `period` - 时间范围（天数）
    /// * `user_id` - 可选的用户ID筛选
    ///
    /// # Returns
    /// * `MijiResult<NotificationStatistics>` - 统计信息
    pub async fn get_statistics(
        &self,
        db: &DatabaseConnection,
        period_days: i64,
        user_id: Option<String>,
    ) -> MijiResult<NotificationStatistics> {
        use ::entity::notification_logs;
        use chrono::{Duration, Utc};
        use sea_orm::*;
        use std::collections::HashMap;

        // 计算起始时间
        let start_date = Utc::now() - Duration::days(period_days);

        // 构建查询
        let logs = notification_logs::Entity::find()
            .filter(notification_logs::Column::CreatedAt.gte(start_date))
            .all(db)
            .await?;

        // TODO: 如需按用户筛选，需通过 reminder -> todo -> owner_id 两层关联
        let _user_id = user_id; // 暂时忽略用户筛选参数

        // 统计数据
        let mut total = 0i64;
        let mut success = 0i64;
        let mut failed = 0i64;
        let mut pending = 0i64;
        let mut by_type: HashMap<String, i64> = HashMap::new();
        let mut by_priority: HashMap<String, i64> = HashMap::new();

        for log in logs {
            total += 1;

            // 按状态统计
            match log.status.as_str() {
                "Sent" => success += 1,
                "Failed" => failed += 1,
                "Pending" => pending += 1,
                _ => {}
            }

            // 按类型统计
            *by_type.entry(log.notification_type.clone()).or_insert(0) += 1;

            // 按优先级统计
            *by_priority.entry(log.priority.clone()).or_insert(0) += 1;
        }

        Ok(NotificationStatistics {
            total,
            success,
            failed,
            pending,
            by_type,
            by_priority,
        })
    }

    /// 获取每日趋势数据
    ///
    /// # Arguments
    /// * `db` - 数据库连接
    /// * `period_days` - 时间范围（天数）
    /// * `user_id` - 可选的用户ID筛选
    ///
    /// # Returns
    /// * `MijiResult<Vec<DailyTrend>>` - 每日趋势数据
    pub async fn get_daily_trend(
        &self,
        db: &DatabaseConnection,
        period_days: i64,
        user_id: Option<String>,
    ) -> MijiResult<Vec<DailyTrend>> {
        use ::entity::notification_logs;
        use chrono::{Duration, TimeZone, Utc};
        use sea_orm::*;
        use std::collections::HashMap;

        // 计算起始时间
        let start_date = Utc::now() - Duration::days(period_days);

        // 构建查询
        let logs = notification_logs::Entity::find()
            .filter(notification_logs::Column::CreatedAt.gte(start_date))
            .all(db)
            .await?;

        // TODO: 如需按用户筛选，需通过 reminder -> todo -> owner_id 两层关联
        let _user_id = user_id; // 暂时忽略用户筛选参数

        // 按日期分组统计
        let mut daily_stats: HashMap<String, (i64, i64)> = HashMap::new();

        for log in logs {
            let date = log.created_at.date_naive().to_string();
            let stats = daily_stats.entry(date).or_insert((0, 0));

            match log.status.as_str() {
                "Sent" => stats.0 += 1,
                "Failed" => stats.1 += 1,
                _ => {}
            }
        }

        // 转换为趋势数据
        let mut trends: Vec<DailyTrend> = daily_stats
            .into_iter()
            .map(|(date_str, (success, failed))| {
                let date = chrono::NaiveDate::parse_from_str(&date_str, "%Y-%n-%d")
                    .unwrap_or_else(|_| Utc::now().naive_utc().date());
                let datetime = Utc.from_utc_datetime(&date.and_hms_opt(0, 0, 0).unwrap());
                
                DailyTrend {
                    date: datetime.with_timezone(&chrono::FixedOffset::east_opt(8 * 3600).unwrap()),
                    success,
                    failed,
                }
            })
            .collect();

        // 按日期排序
        trends.sort_by(|a, b| a.date.cmp(&b.date));

        Ok(trends)
    }
}

impl Default for StatisticsService {
    fn default() -> Self {
        Self::new()
    }
}

/// 通知统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationStatistics {
    pub total: i64,
    pub success: i64,
    pub failed: i64,
    pub pending: i64,
    pub by_type: std::collections::HashMap<String, i64>,
    pub by_priority: std::collections::HashMap<String, i64>,
}

/// 每日趋势数据点
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyTrend {
    pub date: chrono::DateTime<chrono::FixedOffset>,
    pub success: i64,
    pub failed: i64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_notification_type_as_str() {
        assert_eq!(NotificationType::TodoReminder.as_str(), "TodoReminder");
        assert_eq!(NotificationType::BillReminder.as_str(), "BillReminder");
        assert_eq!(
            NotificationType::Custom("Test".to_string()).as_str(),
            "Test"
        );
    }

    #[test]
    fn test_notification_priority_order() {
        assert!(NotificationPriority::Low < NotificationPriority::Normal);
        assert!(NotificationPriority::Normal < NotificationPriority::High);
        assert!(NotificationPriority::High < NotificationPriority::Urgent);
    }

    #[test]
    fn test_default_priority() {
        assert_eq!(default_priority(), NotificationPriority::Normal);
    }
}
