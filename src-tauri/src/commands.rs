// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Commands
// Create   Date:  2025-06-15 15:49:12
// Last Modified:  2025-06-18 15:25:23
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
use chrono::{Duration, Utc};
use common::{
    AppState, TokenResponse, TokenStatus,
    argon2id::{helper::Argon2Helper, store_hash::StoredHash},
    error::{AuthError, MijiErrorDto, MijiResult, to_dto},
    jwt::JwtHelper,
};
use log::info;
use tauri::{Builder, State, Wry};

pub fn init_commands(builder: Builder<Wry>) -> Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![
        greet,
        pwd_hash,
        check_pwd,
        generate_token,
        is_verify_token
    ])
}

#[tauri::command]
async fn greet(name: String, state: State<'_, AppState>) -> Result<String, String> {
    let _db = state.db.clone();
    info!("Greet {name}");
    Ok(format!("Hello, {name}! You've been greeted from Rust!"))
}

#[tauri::command]
async fn pwd_hash(pwd: String) -> String {
    let argon = Argon2Helper::new().unwrap();
    let pwds = argon.create_hashed_password(&pwd).unwrap();
    serde_json::to_string(&pwds).unwrap()
}

#[tauri::command]
async fn check_pwd(pwd: String, pwd_hash: String) -> Result<bool, MijiErrorDto> {
    check_password_hash(&pwd, &pwd_hash).map_err(to_dto)
}

#[tauri::command]
async fn generate_token(
    user_id: String,
    role: String,
    state: tauri::State<'_, AppState>,
) -> Result<TokenResponse, MijiErrorDto> {
    let credentials = &state.credentials.lock().await;
    let jwt_helper = JwtHelper::new(credentials.jwt_secret.to_string());

    let token = jwt_helper
        .generate_token(&user_id, &role, credentials.expired_at)
        .map_err(to_dto)?;
    let expires_at = Utc::now()
        .checked_add_signed(Duration::hours(credentials.expired_at))
        .expect("valid timestamp")
        .timestamp() as usize;
    Ok(TokenResponse { token, expires_at })
}

#[tauri::command]
async fn is_verify_token(
    state: State<'_, AppState>,
    token: String,
) -> Result<TokenStatus, MijiErrorDto> {
    let credentials = &state.credentials.lock().await;
    let jwt_helper = JwtHelper::new(credentials.jwt_secret.to_string());

    match jwt_helper.verify_token(&token) {
        Ok(claims) => {
            let now = Utc::now().timestamp() as usize;
            if claims.exp < now {
                Ok(TokenStatus::Expired)
            } else {
                Ok(TokenStatus::Valid)
            }
        }
        Err(_) => Ok(TokenStatus::Invalid),
    }
}

fn check_password_hash(password: &str, pwd_hash: &str) -> MijiResult<bool> {
    let store: StoredHash = serde_json::from_str(pwd_hash).unwrap();
    let helper = Argon2Helper::new()?;
    let verity_hash = helper.verify_hashed_password(password, &store)?;
    if !verity_hash {
        Err(AuthError::UserAndPasswordFailure {
            code: common::business_code::BusinessCode::Unauthorized,

            message: "User or Password is failure".to_string(),
        })?
    }
    Ok(true)
}
