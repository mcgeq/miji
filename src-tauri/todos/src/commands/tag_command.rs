// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           tag_command.rs
// Description:    About Tag Command
// Create   Date:  2025-06-05 23:31:23
// Last Modified:  2025-06-05 23:36:18
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{
    AppState,
    error::{MijiErrorDto, to_dto},
};
use tauri::State;

use crate::{
    dto::{CreateOrUpdateForm, PaginationParams, TagResponse},
    handlers::TagHandler,
};

#[tauri::command]
pub async fn list_tag(
    pagination: PaginationParams,
    state: State<'_, AppState>,
) -> Result<Vec<TagResponse>, MijiErrorDto> {
    TagHandler::list(pagination, state).await.map_err(to_dto)
}

#[tauri::command]
pub async fn create_tag(
    param: CreateOrUpdateForm,
    state: State<'_, AppState>,
) -> Result<TagResponse, MijiErrorDto> {
    TagHandler::create(&param, state).await.map_err(to_dto)
}

#[tauri::command]
pub async fn update_tag(
    serial_num: String,
    param: CreateOrUpdateForm,
    state: State<'_, AppState>,
) -> Result<TagResponse, MijiErrorDto> {
    TagHandler::update(serial_num, &param, state)
        .await
        .map_err(to_dto)
}

#[tauri::command]
pub async fn delete_tag(
    serial_num: String,
    state: State<'_, AppState>,
) -> Result<TagResponse, MijiErrorDto> {
    TagHandler::delete(serial_num, state).await.map_err(to_dto)
}
