// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           project_command.rs
// Description:    About Project Command
// Create   Date:  2025-06-05 23:31:38
// Last Modified:  2025-06-05 23:35:27
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{
    AppState,
    error::{MijiErrorDto, to_dto},
};
use tauri::State;

use crate::{
    dto::{CreateOrUpdateForm, PaginationParams, ProjectResponse},
    services::ProjectService,
};

#[tauri::command]
pub async fn list_project(
    pagination: PaginationParams,
    state: State<'_, AppState>,
) -> Result<Vec<ProjectResponse>, MijiErrorDto> {
    ProjectService::list(state, &pagination)
        .await
        .map_err(to_dto)
}

#[tauri::command]
pub async fn create_project(
    param: CreateOrUpdateForm,
    state: State<'_, AppState>,
) -> Result<ProjectResponse, MijiErrorDto> {
    ProjectService::create(state, &param).await.map_err(to_dto)
}

#[tauri::command]
pub async fn update_project(
    serial_num: String,
    param: CreateOrUpdateForm,
    state: State<'_, AppState>,
) -> Result<ProjectResponse, MijiErrorDto> {
    ProjectService::update(state, &serial_num, &param)
        .await
        .map_err(to_dto)
}

#[tauri::command]
pub async fn delete_project(
    serial_num: String,
    state: State<'_, AppState>,
) -> Result<ProjectResponse, MijiErrorDto> {
    ProjectService::delete(state, &serial_num)
        .await
        .map_err(to_dto)
}
