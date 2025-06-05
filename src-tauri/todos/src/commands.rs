// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Commands
// Create   Date:  2025-06-04 22:01:52
// Last Modified:  2025-06-05 23:13:52
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{
    AppState,
    error::{MijiErrorDto, to_dto},
};
use tauri::State;

use crate::{
    dto::{
        CreateOrUpdateForm, PaginationParams, ProjectResponse, TagResponse, TodoInput,
        TodoListResult, TodoResponse,
    },
    handlers::{TagHandler, TodoHandler},
    services::ProjectService,
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
