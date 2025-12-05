// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           notification_commands.rs
// Description:    通知相关 Tauri 命令
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use tauri::AppHandle;

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
