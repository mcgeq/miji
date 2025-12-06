// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           notification_commands.rs
// Description:    通知相关 Tauri 命令
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use common::{NotificationStatistics, StatisticsService};
use tauri::{AppHandle, State};
use crate::AppStateInner;

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
    state: State<'_, AppStateInner>,
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
        .get_statistics(&state.db, period_days, user_id)
        .await
        .map_err(|e| {
            tracing::error!("获取通知统计失败: {}", e);
            e.to_string()
        })
}
