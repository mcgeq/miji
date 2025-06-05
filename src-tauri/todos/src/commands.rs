// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Commands
// Create   Date:  2025-06-04 22:01:52
// Last Modified:  2025-06-05 19:31:19
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{
    AppState,
    error::{MijiErrorDto, to_dto},
};
use tauri::State;

use crate::{
    dto::{PaginationParams, ProjectInfo, TodoId, TodoInput, TodoListResult, TodoResponse},
    handlers::TodoHandler,
};

#[tauri::command]
pub async fn list_todo(
    pagination: PaginationParams,
    state: State<'_, AppState>,
) -> Result<TodoListResult, MijiErrorDto> {
    TodoHandler::list(pagination, state).await.map_err(to_dto)
}

#[tauri::command]
pub async fn create_todo(
    param: TodoInput,
    state: State<'_, AppState>,
) -> Result<TodoResponse, MijiErrorDto> {
    TodoHandler::create(param, state).await.map_err(to_dto)
}

#[tauri::command]
pub async fn update_todo(
    serial_num: String,
    param: TodoInput,
    state: State<'_, AppState>,
) -> Result<TodoResponse, MijiErrorDto> {
    TodoHandler::update(serial_num, param, state)
        .await
        .map_err(to_dto)
}

#[tauri::command]
pub async fn delete_todo(
    serial_num: String,
    state: State<'_, AppState>,
) -> Result<TodoResponse, MijiErrorDto> {
    TodoHandler::delete(serial_num, state).await.map_err(to_dto)
}

#[tauri::command]
pub async fn list_tag(
    pagination: PaginationParams,
    state: State<'_, AppState>,
) -> Result<String, MijiErrorDto> {
    Ok("list".to_string())
}

#[tauri::command]
pub async fn create_tag(state: State<'_, AppState>) -> Result<String, MijiErrorDto> {
    Ok("create".to_string())
}

#[tauri::command]
pub async fn update_tag(state: State<'_, AppState>) -> Result<String, MijiErrorDto> {
    Ok("create".to_string())
}

#[tauri::command]
pub async fn delete_tag(param: TodoId, state: State<'_, AppState>) -> Result<String, MijiErrorDto> {
    Ok("delete".to_string())
}

#[tauri::command]
pub async fn list_project(
    pagination: PaginationParams,
    state: State<'_, AppState>,
) -> Result<String, MijiErrorDto> {
    Ok("list".to_string())
}

#[tauri::command]
pub async fn create_project(
    param: ProjectInfo,
    state: State<'_, AppState>,
) -> Result<String, MijiErrorDto> {
    Ok("create".to_string())
}

#[tauri::command]
pub async fn update_project(state: State<'_, AppState>) -> Result<String, MijiErrorDto> {
    Ok("create".to_string())
}

#[tauri::command]
pub async fn delete_project(
    param: TodoId,
    state: State<'_, AppState>,
) -> Result<String, MijiErrorDto> {
    Ok("delete".to_string())
}
