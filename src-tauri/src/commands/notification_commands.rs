// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           notification_commands.rs
// Description:    通知相关 Tauri 命令
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use common::{AppState, NotificationStatistics, StatisticsService};
use entity::notification_settings;
use sea_orm::{ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, Set};
use serde::{Deserialize, Serialize};
use tauri::{AppHandle, State};

/// 请求通知权限
///
/// # Arguments
/// * `app` - Tauri 应用句柄
///
/// # Returns
/// * `Result<bool, String>` - 是否已授予权限
#[tauri::command]
pub async fn request_notification_permission(_app: AppHandle) -> Result<bool, String> {
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        use crate::mobiles::notification_setup;
        notification_setup::request_notification_permission(&_app).await
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        Ok(true) // 桌面端默认有权限
    }
}

/// 检查通知权限状态
///
/// # Arguments
/// * `app` - Tauri 应用句柄
///
/// # Returns
/// * `Result<bool, String>` - 是否已授予权限
#[tauri::command]
pub fn check_notification_permission(_app: AppHandle) -> Result<bool, String> {
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        use crate::mobiles::notification_setup;
        notification_setup::check_notification_permission(&_app)
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        Ok(true) // 桌面端默认有权限
    }
}

/// 打开系统通知设置页面
///
/// # Arguments
/// * `app` - Tauri 应用句柄
///
/// # Returns
/// * `Result<(), String>` - 操作结果
#[tauri::command]
pub fn open_notification_settings(_app: AppHandle) -> Result<(), String> {
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        use crate::mobiles::notification_setup;
        notification_setup::open_notification_settings(&_app)
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        Err("桌面端不支持此功能".to_string())
    }
}

/// 获取通知统计信息
///
/// # Arguments
/// * `state` - 应用状态
/// * `period` - 时间范围 (7d, 30d, 90d)
///
/// # Returns
/// * `Result<NotificationStatistics, String>` - 统计信息
#[tauri::command]
pub async fn notification_statistics_get(
    state: State<'_, AppState>,
    period: String,
) -> Result<NotificationStatistics, String> {
    tracing::debug!("获取通知统计: period={}", period);

    // 解析时间范围
    let period_days = match period.as_str() {
        "7d" => 7,
        "30d" => 30,
        "90d" => 90,
        _ => return Err(format!("不支持的时间范围: {}", period)),
    };

    // 创建统计服务
    let service = StatisticsService::new();

    // 获取当前用户ID（如果需要按用户筛选）
    // TODO: 从 state 或 session 获取当前用户ID
    let user_id: Option<String> = None;

    // 查询统计数据
    service
        .get_statistics(state.db.as_ref(), period_days, user_id)
        .await
        .map_err(|e| {
            tracing::error!("获取通知统计失败: {}", e);
            e.to_string()
        })
}

// ============================================================================
// 通知设置管理命令
// ============================================================================

/// 通知设置响应结构
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationSettingsResponse {
    pub serial_num: String,
    pub user_id: String,
    pub notification_type: String,
    pub enabled: bool,
    pub quiet_hours_start: Option<String>,
    pub quiet_hours_end: Option<String>,
    pub quiet_days: Option<Vec<String>>,
    pub sound_enabled: bool,
    pub vibration_enabled: bool,
    pub created_at: String,
    pub updated_at: Option<String>,
}

impl From<notification_settings::Model> for NotificationSettingsResponse {
    fn from(model: notification_settings::Model) -> Self {
        // 解析 quiet_days JSON
        let quiet_days = model
            .quiet_days
            .and_then(|json| serde_json::from_value::<Vec<String>>(json).ok());

        // 转换 Time 为字符串 (HH:MM 格式)
        let quiet_hours_start = model
            .quiet_hours_start
            .map(|t| t.format("%H:%M").to_string());
        let quiet_hours_end = model.quiet_hours_end.map(|t| t.format("%H:%M").to_string());

        Self {
            serial_num: model.serial_num,
            user_id: model.user_id,
            notification_type: model.notification_type,
            enabled: model.enabled,
            quiet_hours_start,
            quiet_hours_end,
            quiet_days,
            sound_enabled: model.sound_enabled,
            vibration_enabled: model.vibration_enabled,
            created_at: model.created_at.to_string(),
            updated_at: model.updated_at.map(|dt| dt.to_string()),
        }
    }
}

/// 通知设置表单
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationSettingsForm {
    pub notification_type: String,
    pub enabled: bool,
    pub quiet_hours_start: Option<String>,
    pub quiet_hours_end: Option<String>,
    pub quiet_days: Option<Vec<String>>,
    pub sound_enabled: Option<bool>,
    pub vibration_enabled: Option<bool>,
}

/// 获取所有通知设置
#[tauri::command]
pub async fn notification_settings_get_all(
    state: State<'_, AppState>,
    user_id: String,
) -> Result<Vec<NotificationSettingsResponse>, String> {
    tracing::debug!("获取用户通知设置: user_id={}", user_id);

    let settings = notification_settings::Entity::find()
        .filter(notification_settings::Column::UserId.eq(&user_id))
        .all(state.db.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("查询通知设置失败: {}", e);
            e.to_string()
        })?;

    Ok(settings.into_iter().map(Into::into).collect())
}

/// 获取单个通知类型的设置
#[tauri::command]
pub async fn notification_settings_get(
    state: State<'_, AppState>,
    user_id: String,
    notification_type: String,
) -> Result<Option<NotificationSettingsResponse>, String> {
    tracing::debug!(
        "获取通知设置: user_id={}, type={}",
        user_id,
        notification_type
    );

    let setting = notification_settings::Entity::find()
        .filter(notification_settings::Column::UserId.eq(&user_id))
        .filter(notification_settings::Column::NotificationType.eq(&notification_type))
        .one(state.db.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("查询通知设置失败: {}", e);
            e.to_string()
        })?;

    Ok(setting.map(Into::into))
}

/// 更新通知设置
#[tauri::command]
pub async fn notification_settings_update(
    state: State<'_, AppState>,
    user_id: String,
    settings: NotificationSettingsForm,
) -> Result<NotificationSettingsResponse, String> {
    use common::utils::date::DateUtils;

    tracing::debug!(
        "更新通知设置: user_id={}, type={}",
        user_id,
        settings.notification_type
    );

    // 查找现有设置
    let existing = notification_settings::Entity::find()
        .filter(notification_settings::Column::UserId.eq(&user_id))
        .filter(notification_settings::Column::NotificationType.eq(&settings.notification_type))
        .one(state.db.as_ref())
        .await
        .map_err(|e| e.to_string())?;

    let model = if let Some(existing_model) = existing {
        // 更新现有设置
        let mut active: notification_settings::ActiveModel = existing_model.into();
        active.enabled = Set(settings.enabled);

        // 解析时间字符串为 Time (HH:MM 格式)
        active.quiet_hours_start = Set(settings
            .quiet_hours_start
            .and_then(|s| chrono::NaiveTime::parse_from_str(&s, "%H:%M").ok()));
        active.quiet_hours_end = Set(settings
            .quiet_hours_end
            .and_then(|s| chrono::NaiveTime::parse_from_str(&s, "%H:%M").ok()));

        // 转换 quiet_days 为 JSON
        if let Some(days) = settings.quiet_days {
            active.quiet_days = Set(Some(serde_json::to_value(days).unwrap()));
        }

        if let Some(sound) = settings.sound_enabled {
            active.sound_enabled = Set(sound);
        }
        if let Some(vibration) = settings.vibration_enabled {
            active.vibration_enabled = Set(vibration);
        }

        active.updated_at = Set(Some(DateUtils::local_now()));

        active.update(state.db.as_ref()).await.map_err(|e| {
            tracing::error!("更新通知设置失败: {}", e);
            e.to_string()
        })?
    } else {
        // 创建新设置
        use common::utils::uuid::McgUuid;

        let quiet_days_json = settings
            .quiet_days
            .map(|days| serde_json::to_value(days).unwrap());

        // 解析时间字符串为 Time
        let quiet_hours_start = settings
            .quiet_hours_start
            .and_then(|s| chrono::NaiveTime::parse_from_str(&s, "%H:%M").ok());
        let quiet_hours_end = settings
            .quiet_hours_end
            .and_then(|s| chrono::NaiveTime::parse_from_str(&s, "%H:%M").ok());

        let new_setting = notification_settings::ActiveModel {
            serial_num: Set(McgUuid::uuid(38)),
            user_id: Set(user_id),
            notification_type: Set(settings.notification_type),
            enabled: Set(settings.enabled),
            quiet_hours_start: Set(quiet_hours_start),
            quiet_hours_end: Set(quiet_hours_end),
            quiet_days: Set(quiet_days_json),
            sound_enabled: Set(settings.sound_enabled.unwrap_or(true)),
            vibration_enabled: Set(settings.vibration_enabled.unwrap_or(true)),
            created_at: Set(DateUtils::local_now()),
            updated_at: Set(None),
        };

        new_setting.insert(state.db.as_ref()).await.map_err(|e| {
            tracing::error!("创建通知设置失败: {}", e);
            e.to_string()
        })?
    };

    tracing::info!("通知设置已更新: type={}", model.notification_type);
    Ok(model.into())
}

/// 批量更新通知设置
#[tauri::command]
pub async fn notification_settings_batch_update(
    state: State<'_, AppState>,
    user_id: String,
    settings_list: Vec<NotificationSettingsForm>,
) -> Result<Vec<NotificationSettingsResponse>, String> {
    tracing::debug!(
        "批量更新通知设置: user_id={}, count={}",
        user_id,
        settings_list.len()
    );

    let mut results = Vec::new();

    for settings in settings_list {
        let result = notification_settings_update(state.clone(), user_id.clone(), settings).await?;
        results.push(result);
    }

    tracing::info!("批量更新完成: count={}", results.len());
    Ok(results)
}

/// 重置通知设置为默认值
#[tauri::command]
pub async fn notification_settings_reset(
    state: State<'_, AppState>,
    user_id: String,
) -> Result<(), String> {
    tracing::debug!("重置通知设置: user_id={}", user_id);

    // 删除用户的所有通知设置
    notification_settings::Entity::delete_many()
        .filter(notification_settings::Column::UserId.eq(&user_id))
        .exec(state.db.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("删除通知设置失败: {}", e);
            e.to_string()
        })?;

    tracing::info!("通知设置已重置");
    Ok(())
}

// ============================================================================
// 通知日志管理命令
// ============================================================================

/// 通知日志响应结构
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationLogResponse {
    pub serial_num: String,
    pub reminder_serial_num: String,
    pub notification_type: String,
    pub priority: String,
    pub status: String,
    pub sent_at: Option<String>,
    pub error_message: Option<String>,
    pub retry_count: i32,
    pub last_retry_at: Option<String>,
    pub created_at: String,
    pub updated_at: Option<String>,
}

impl From<entity::notification_logs::Model> for NotificationLogResponse {
    fn from(model: entity::notification_logs::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            reminder_serial_num: model.reminder_serial_num,
            notification_type: model.notification_type,
            priority: model.priority,
            status: model.status,
            sent_at: model.sent_at.map(|dt| dt.to_string()),
            error_message: model.error_message,
            retry_count: model.retry_count,
            last_retry_at: model.last_retry_at.map(|dt| dt.to_string()),
            created_at: model.created_at.to_string(),
            updated_at: model.updated_at.map(|dt| dt.to_string()),
        }
    }
}

/// 通知日志查询参数
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationLogQueryParams {
    pub page: Option<u64>,
    pub size: Option<u64>,
    pub r#type: Option<String>,
    pub status: Option<String>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
}

/// 通知日志列表响应
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationLogListResponse {
    pub logs: Vec<NotificationLogResponse>,
    pub total: u64,
    pub page: u64,
    pub size: u64,
}

/// 获取通知日志列表
#[tauri::command]
pub async fn notification_logs_list(
    state: State<'_, AppState>,
    params: NotificationLogQueryParams,
) -> Result<NotificationLogListResponse, String> {
    use entity::notification_logs;
    use sea_orm::{Order, PaginatorTrait, QueryOrder};

    tracing::debug!("获取通知日志列表: params={:?}", params);

    let page = params.page.unwrap_or(1);
    let size = params.size.unwrap_or(20);

    // 构建查询
    let mut query = notification_logs::Entity::find();

    // 按类型筛选
    if let Some(notification_type) = params.r#type {
        query = query.filter(notification_logs::Column::NotificationType.eq(notification_type));
    }

    // 按状态筛选
    if let Some(status) = params.status {
        query = query.filter(notification_logs::Column::Status.eq(status));
    }

    // 按时间范围筛选
    // TODO: 实现 start_date 和 end_date 筛选

    // 按创建时间倒序
    query = query.order_by(notification_logs::Column::CreatedAt, Order::Desc);

    // 分页查询
    let paginator = query.paginate(state.db.as_ref(), size);
    let total = paginator.num_items().await.map_err(|e| e.to_string())?;
    let logs = paginator
        .fetch_page(page - 1)
        .await
        .map_err(|e| e.to_string())?;

    Ok(NotificationLogListResponse {
        logs: logs.into_iter().map(Into::into).collect(),
        total,
        page,
        size,
    })
}

/// 获取单个通知日志
#[tauri::command]
pub async fn notification_log_get(
    state: State<'_, AppState>,
    id: String,
) -> Result<NotificationLogResponse, String> {
    use entity::notification_logs;

    tracing::debug!("获取通知日志: id={}", id);

    let log = notification_logs::Entity::find_by_id(&id)
        .one(state.db.as_ref())
        .await
        .map_err(|e| e.to_string())?
        .ok_or_else(|| "通知日志不存在".to_string())?;

    Ok(log.into())
}

/// 删除通知日志
#[tauri::command]
pub async fn notification_log_delete(state: State<'_, AppState>, id: String) -> Result<(), String> {
    use entity::notification_logs;

    tracing::debug!("删除通知日志: id={}", id);

    notification_logs::Entity::delete_by_id(&id)
        .exec(state.db.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("删除通知日志失败: {}", e);
            e.to_string()
        })?;

    tracing::info!("通知日志已删除");
    Ok(())
}

/// 批量删除通知日志
#[tauri::command]
pub async fn notification_logs_batch_delete(
    state: State<'_, AppState>,
    ids: Vec<String>,
) -> Result<(), String> {
    use entity::notification_logs;

    tracing::debug!("批量删除通知日志: count={}", ids.len());

    notification_logs::Entity::delete_many()
        .filter(notification_logs::Column::SerialNum.is_in(ids.clone()))
        .exec(state.db.as_ref())
        .await
        .map_err(|e| {
            tracing::error!("批量删除通知日志失败: {}", e);
            e.to_string()
        })?;

    tracing::info!("批量删除完成: count={}", ids.len());
    Ok(())
}

/// 重试失败的通知
#[tauri::command]
pub async fn notification_log_retry(
    _state: State<'_, AppState>,
    _id: String,
) -> Result<(), String> {
    // TODO: 实现重试逻辑
    // 1. 获取日志记录
    // 2. 重新创建 NotificationRequest
    // 3. 调用 NotificationService::send()
    // 4. 更新日志状态

    tracing::warn!("通知重试功能待实现");
    Err("功能待实现".to_string())
}
