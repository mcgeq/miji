// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Money Commands
// Create   Date:  2025-06-06 13:20:31
// Last Modified:  2025-06-06 14:03:30
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{AppState, error::MijiErrorDto};
use tauri::State;

#[tauri::command]
pub async fn income(state: State<'_, AppState>) -> Result<String, MijiErrorDto> {
    Ok("income".to_string())
}

#[tauri::command]
pub async fn expenditure(state: State<'_, AppState>) -> Result<String, MijiErrorDto> {
    Ok("expenditure".to_string())
}
