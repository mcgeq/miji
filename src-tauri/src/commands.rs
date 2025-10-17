// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Commands
// Create   Date:  2025-06-15 15:49:12
// Last Modified:  2025-08-13 16:59:35
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use auth::{commands as auth_cmd, services::user::UserService};
use chrono::{Duration, Utc};
use common::{
    AppState, TokenResponse, TokenStatus,
    argon2id::{helper::Argon2Helper, store_hash::StoredHash},
    error::{AppError, MijiResult},
    jwt::JwtHelper,
    response::ApiResponse,
};
use healths::command as health_cmd;
use money::command as money_cmd;
use tauri::{AppHandle, Builder, Emitter, Manager, State, Wry};
use todos::command as todo_cmd;
use tracing::info;

pub fn init_commands(builder: Builder<Wry>) -> Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![
        set_complete,
        greet,
        pwd_hash,
        check_pwd,
        generate_token,
        is_verify_token,
        minimize_to_tray,
        restore_from_tray,
        toggle_window_visibility,
        close_app,
        get_close_behavior_preference,
        set_close_behavior_preference,
        is_user_logged_in,
        auth_cmd::exists_user,
        auth_cmd::create_user,
        auth_cmd::get_user_with_email,
        auth_cmd::update_user,
        todo_cmd::todo_get,
        todo_cmd::todo_create,
        todo_cmd::todo_update,
        todo_cmd::todo_delete,
        todo_cmd::todo_toggle,
        todo_cmd::todo_list,
        todo_cmd::todo_list_paged,
        money_cmd::total_assets,
        money_cmd::account_get,
        money_cmd::account_create,
        money_cmd::account_update,
        money_cmd::account_update_active,
        money_cmd::account_delete,
        money_cmd::account_list,
        money_cmd::account_list_paged,
        money_cmd::currency_create,
        money_cmd::currency_get,
        money_cmd::currency_update,
        money_cmd::currency_delete,
        money_cmd::currencies_list,
        money_cmd::currencies_list_paged,
        money_cmd::transaction_create,
        money_cmd::transaction_transfer_create,
        money_cmd::transaction_transfer_delete,
        money_cmd::transaction_transfer_update,
        money_cmd::transaction_query_income_and_expense,
        money_cmd::transaction_get_stats,
        money_cmd::transaction_get,
        money_cmd::transaction_update,
        money_cmd::transaction_delete,
        money_cmd::transaction_list,
        money_cmd::transaction_list_paged,
        money_cmd::installment_plan_get,
        money_cmd::installment_pending_list,
        money_cmd::installment_calculate,
        money_cmd::budget_get,
        money_cmd::budget_create,
        money_cmd::budget_update,
        money_cmd::budget_update_active,
        money_cmd::budget_delete,
        money_cmd::budget_list_paged,
        money_cmd::bil_reminder_get,
        money_cmd::bil_reminder_create,
        money_cmd::bil_reminder_update,
        money_cmd::bil_reminder_delete,
        money_cmd::bil_reminder_list,
        money_cmd::bil_reminder_list_paged,
        money_cmd::category_get,
        money_cmd::category_create,
        money_cmd::category_update,
        money_cmd::category_delete,
        money_cmd::category_list,
        money_cmd::category_list_paged,
        money_cmd::sub_category_get,
        money_cmd::sub_category_create,
        money_cmd::sub_category_update,
        money_cmd::sub_category_delete,
        money_cmd::sub_category_list,
        money_cmd::sub_category_list_paged,
        money_cmd::family_member_list,
        health_cmd::period_record_create,
        health_cmd::period_record_update,
        health_cmd::period_record_delete,
        health_cmd::period_record_list_paged,
        health_cmd::period_daily_record_get,
        health_cmd::period_daily_record_create,
        health_cmd::period_daily_record_update,
        health_cmd::period_daily_record_delete,
        health_cmd::period_daily_record_list_paged,
        health_cmd::period_settings_get,
        health_cmd::period_settings_create,
        health_cmd::period_settings_update,
    ])
}

#[tauri::command]
pub async fn set_complete(
    app: AppHandle,
    state: State<'_, AppState>,
    task: String,
) -> Result<(), ()> {
    #[cfg(desktop)] // 只在桌面平台执行
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
async fn greet(name: String, state: State<'_, AppState>) -> Result<ApiResponse<String>, String> {
    let _db = state.db.clone();
    info!("Greet {name}");
    Ok(ApiResponse::success(format!(
        "Hello, {name}! You've been greeted from Rust!"
    )))
}

#[tauri::command]
async fn pwd_hash(pwd: String) -> ApiResponse<String> {
    let result = (|| -> MijiResult<String> {
        let argon = Argon2Helper::new()?;
        let pwds = argon.create_hashed_password(&pwd)?;
        let json_str = serde_json::to_string(&pwds).map_err(|e| {
            AppError::simple(
                common::business_code::BusinessCode::SerializationError,
                format!("Failed to serialize password hash: {e}"),
            )
        })?;
        Ok(json_str)
    })();

    ApiResponse::from_result(result)
}

#[tauri::command]
async fn check_pwd(
    state: State<'_, AppState>,
    pwd: String,
    user_id: String,
) -> Result<ApiResponse<bool>, String> {
    let service = UserService::get_user_service();
    let pwd_hash = service.get_user_password(&state.db, user_id).await;
    let result = check_password_hash(&pwd, &pwd_hash.ok().unwrap());
    Ok(ApiResponse::from_result(result))
}

#[tauri::command]
async fn generate_token(
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
async fn is_verify_token(
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

fn check_password_hash(password: &str, pwd_hash: &str) -> MijiResult<bool> {
    let store: StoredHash = serde_json::from_str(pwd_hash).map_err(|e| {
        AppError::simple(
            common::business_code::BusinessCode::DeserializationError,
            format!("Failed to parse password hash: {e}"),
        )
    })?;

    let helper = Argon2Helper::new()?;
    let verity_hash = helper.verify_hashed_password(password, &store)?;

    if !verity_hash {
        return Err(AppError::simple(
            common::business_code::BusinessCode::AuthenticationFailed,
            "User or Password is failure",
        ));
    }

    Ok(true)
}

#[tauri::command]
async fn minimize_to_tray(app: AppHandle) -> Result<(), String> {
    #[cfg(desktop)]
    {
        if let Some(window) = app.get_webview_window("main") {
            window.hide().map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

#[tauri::command]
async fn restore_from_tray(app: AppHandle) -> Result<(), String> {
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
async fn toggle_window_visibility(app: AppHandle) -> Result<(), String> {
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
async fn close_app(app: AppHandle) -> Result<(), String> {
    app.exit(0);
    Ok(())
}

use std::collections::HashMap;
use std::sync::Mutex;

// 全局状态存储用户偏好
pub type AppPreferences = Mutex<HashMap<String, String>>;

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
        // 使用eval执行JavaScript来检查localStorage中的token
        let _script = r#"
            (() => {
                try {
                    const token = localStorage.getItem('auth_token');
                    return token && token !== 'null' && token !== '';
                } catch (e) {
                    return false;
                }
            })()
        "#;

        // 由于eval不能直接返回值，我们使用一个不同的方法
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
