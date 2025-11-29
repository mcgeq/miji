// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           system_commands.rs
// Description:    系统级Tauri命令
// Create   Date:  2025-11-11
// -----------------------------------------------------------------------------

use auth::services::user::UserService;
use chrono::{Duration, Utc};
use common::{
    AppState, TokenResponse, TokenStatus,
    argon2id::{helper::Argon2Helper, store_hash::StoredHash},
    business_code::BusinessCode,
    error::{AppError, MijiResult},
    jwt::JwtHelper,
    response::ApiResponse,
};
use std::collections::HashMap;
use std::sync::Mutex;
use tauri::{AppHandle, Emitter, Manager, State};
use tracing::info;

// ==================== 全局状态 ====================

/// 全局状态存储用户偏好
pub type AppPreferences = Mutex<HashMap<String, String>>;

// ==================== 系统命令 ====================

#[tauri::command]
pub async fn set_complete(
    app: AppHandle,
    state: State<'_, AppState>,
    task: String,
) -> Result<(), ()> {
    #[cfg(desktop)]
    {
        let mut state_lock = state.task.lock().await;
        match task.as_str() {
            "frontend" => state_lock.frontend_task = true,
            "backend" => state_lock.backend_task = true,
            _ => panic!("invalid task completed!"),
        }
        // Check if both tasks are completed
        if state_lock.backend_task && state_lock.frontend_task {
            // Setup is complete, we can close the splashscreen
            // and unhide the main window!
            let splash_window = app.get_window("splashscreen").unwrap();
            let main_window = app.get_window("main").unwrap();
            splash_window.close().unwrap();
            main_window.show().unwrap();
        }
    }
    Ok(())
}

#[tauri::command]
pub async fn greet(
    name: String,
    state: State<'_, AppState>,
) -> Result<ApiResponse<String>, String> {
    let _db = state.db.clone();
    info!("Greet {name}");
    Ok(ApiResponse::success(format!(
        "Hello, {name}! You've been greeted from Rust!"
    )))
}

// ==================== 认证相关命令 ====================

#[tauri::command]
pub async fn pwd_hash(pwd: String) -> ApiResponse<String> {
    let result = (|| -> MijiResult<String> {
        let argon = Argon2Helper::new()?;
        let pwds = argon.create_hashed_password(&pwd)?;
        let json_str = serde_json::to_string(&pwds).map_err(|e| {
            AppError::simple(
                BusinessCode::SerializationError,
                format!("Failed to serialize password hash: {e}"),
            )
        })?;
        Ok(json_str)
    })();

    ApiResponse::from_result(result)
}

#[tauri::command]
pub async fn check_pwd(
    state: State<'_, AppState>,
    pwd: String,
    user_id: String,
) -> Result<ApiResponse<bool>, String> {
    let service = UserService::default();
    let pwd_hash = service.get_user_password(&state.db, user_id).await;
    let result = check_password_hash(&pwd, &pwd_hash.ok().unwrap());
    Ok(ApiResponse::from_result(result))
}

fn check_password_hash(password: &str, pwd_hash: &str) -> MijiResult<bool> {
    let store: StoredHash = serde_json::from_str(pwd_hash).map_err(|e| {
        AppError::simple(
            BusinessCode::DeserializationError,
            format!("Failed to parse password hash: {e}"),
        )
    })?;

    let helper = Argon2Helper::new()?;
    let verity_hash = helper.verify_hashed_password(password, &store)?;

    if !verity_hash {
        return Err(AppError::simple(
            BusinessCode::AuthenticationFailed,
            "User or Password is failure",
        ));
    }

    Ok(true)
}

// ==================== Token相关命令 ====================

#[tauri::command]
pub async fn generate_token(
    user_id: String,
    role: String,
    state: tauri::State<'_, AppState>,
) -> Result<ApiResponse<TokenResponse>, String> {
    let credentials = &state.credentials.lock().await;
    let jwt_helper = JwtHelper::new(credentials.jwt_secret.to_string());

    let result = (|| -> MijiResult<TokenResponse> {
        let token = jwt_helper.generate_token(&user_id, &role, credentials.expired_at)?;

        let expires_at = Utc::now()
            .checked_add_signed(Duration::hours(credentials.expired_at))
            .expect("valid timestamp")
            .timestamp() as usize;

        Ok(TokenResponse { token, expires_at })
    })();

    Ok(ApiResponse::from_result(result))
}

#[tauri::command]
pub async fn is_verify_token(
    state: State<'_, AppState>,
    token: String,
) -> Result<ApiResponse<TokenStatus>, String> {
    let credentials = &state.credentials.lock().await;
    let jwt_helper = JwtHelper::new(credentials.jwt_secret.to_string());

    let status = match jwt_helper.verify_token(&token) {
        Ok(claims) => {
            let now = Utc::now().timestamp() as usize;
            if claims.exp < now {
                TokenStatus::Expired
            } else {
                TokenStatus::Valid
            }
        }
        Err(_) => TokenStatus::Invalid,
    };

    Ok(ApiResponse::success(status))
}

#[tauri::command]
pub async fn refresh_token(
    state: State<'_, AppState>,
    token: String,
) -> Result<ApiResponse<TokenResponse>, String> {
    let credentials = &state.credentials.lock().await;
    let jwt_helper = JwtHelper::new(credentials.jwt_secret.to_string());

    let result = (|| -> MijiResult<TokenResponse> {
        // 验证旧token
        let claims = jwt_helper.verify_token(&token)
            .map_err(|_| AppError::simple(BusinessCode::TokenInvalid, "无效的Token"))?;

        // 检查是否过期（允许已过期的token刷新，但需要在合理时间内）
        let now = Utc::now().timestamp() as usize;
        let expired_grace_period = 24 * 3600; // 允许过期后24小时内刷新
        
        if claims.exp + expired_grace_period < now {
            return Err(AppError::simple(
                BusinessCode::RefreshTokenExpired,
                "Token已过期太久，请重新登录"
            ));
        }

        // 使用旧token中的user_id和role生成新token
        let new_token = jwt_helper.generate_token(
            &claims.sub,  // user_id
            &claims.role,  // role
            credentials.expired_at
        )?;

        let expires_at = Utc::now()
            .checked_add_signed(Duration::hours(credentials.expired_at))
            .expect("valid timestamp")
            .timestamp() as usize;

        Ok(TokenResponse {
            token: new_token,
            expires_at,
        })
    })();

    Ok(ApiResponse::from_result(result))
}

// ==================== 窗口管理命令 ====================

#[tauri::command]
pub async fn minimize_to_tray(app: AppHandle) -> Result<(), String> {
    #[cfg(desktop)]
    {
        if let Some(window) = app.get_webview_window("main") {
            window.hide().map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

#[tauri::command]
pub async fn restore_from_tray(app: AppHandle) -> Result<(), String> {
    #[cfg(desktop)]
    {
        if let Some(window) = app.get_webview_window("main") {
            window.show().map_err(|e| e.to_string())?;
            window.set_focus().map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

#[tauri::command]
pub async fn toggle_window_visibility(app: AppHandle) -> Result<(), String> {
    #[cfg(desktop)]
    {
        if let Some(window) = app.get_webview_window("main") {
            let is_visible = window.is_visible().map_err(|e| e.to_string())?;
            if is_visible {
                window.hide().map_err(|e| e.to_string())?;
            } else {
                window.show().map_err(|e| e.to_string())?;
                window.set_focus().map_err(|e| e.to_string())?;
            }
        }
    }
    Ok(())
}

#[tauri::command]
pub async fn close_app(app: AppHandle) -> Result<(), String> {
    app.exit(0);
    Ok(())
}

// ==================== 用户偏好设置命令 ====================

#[tauri::command]
pub async fn get_close_behavior_preference(
    state: State<'_, AppPreferences>,
) -> Result<Option<String>, String> {
    let preferences = state.lock().map_err(|e| e.to_string())?;
    Ok(preferences.get("closeBehaviorPreference").cloned())
}

#[tauri::command]
pub async fn set_close_behavior_preference(
    preference: String,
    state: State<'_, AppPreferences>,
) -> Result<(), String> {
    let mut preferences = state.lock().map_err(|e| e.to_string())?;
    preferences.insert("closeBehaviorPreference".to_string(), preference);
    Ok(())
}

#[tauri::command]
pub async fn is_user_logged_in(app: AppHandle) -> Result<bool, String> {
    // 通过检查前端localStorage中的token来判断用户是否已登录
    if let Some(window) = app.get_webview_window("main") {
        // 发送事件到前端，让前端返回登录状态
        window
            .emit("check-login-status", ())
            .map_err(|e| e.to_string())?;

        // 暂时返回true，让用户看到关闭对话框
        // 实际实现中应该通过事件回调来获取真实的登录状态
        Ok(true)
    } else {
        Ok(false)
    }
}
