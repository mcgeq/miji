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

use auth::commands as auth_cmd;
use chrono::{Duration, Utc};
use common::{
    AppState, TokenResponse, TokenStatus,
    argon2id::{helper::Argon2Helper, store_hash::StoredHash},
    error::{AppError, MijiResult},
    jwt::JwtHelper,
    response::ApiResponse,
};
use log::info;
use money::command as money_cmd;
use tauri::{Builder, State, Wry};
use todos::command as todo_cmd;

pub fn init_commands(builder: Builder<Wry>) -> Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![
        greet,
        pwd_hash,
        check_pwd,
        generate_token,
        is_verify_token,
        auth_cmd::exists_user,
        auth_cmd::create_user,
        auth_cmd::get_user_with_email,
        auth_cmd::update_user,
        todo_cmd::list,
        todo_cmd::list_paged,
        todo_cmd::create,
        todo_cmd::update,
        todo_cmd::delete,
        money_cmd::total_assets,
        money_cmd::get_account,
        money_cmd::create_account,
        money_cmd::update_account,
        money_cmd::delete_account,
        money_cmd::list_accounts,
        money_cmd::list_accounts_paged,
        money_cmd::create_currency,
        money_cmd::get_currency,
        money_cmd::update_currency,
        money_cmd::delete_currency,
        money_cmd::list_currencies,
        money_cmd::list_currencies_paged,
    ])
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
async fn check_pwd(pwd: String, pwd_hash: String) -> ApiResponse<bool> {
    let result = check_password_hash(&pwd, &pwd_hash);
    ApiResponse::from_result(result)
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
