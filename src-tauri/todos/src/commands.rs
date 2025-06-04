// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Commands
// Create   Date:  2025-06-04 22:01:52
// Last Modified:  2025-06-04 22:15:15
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::AppState;
use tauri::State;

#[tauri::command]
pub async fn list(pagination: u32, state: State<'_, AppState>) -> Result<String> {
    Ok("list".to_string())
}

#[tauri::command]
pub async fn create(state: State<'_, AppState>) -> Result<String> {
    Ok("create".to_string())
}

#[tauri::command]
pub async fn update(state: State<'_, AppState>) -> Result<String> {
    Ok("create".to_string())
}

#[tauri::command]
pub async fn delete(state: State<'_, AppState>) -> Result<String> {
    Ok("delete".to_string())
}
