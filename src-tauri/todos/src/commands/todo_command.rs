// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_command.rs
// Description:    About Todo Command
// Create   Date:  2025-06-05 23:32:01
// Last Modified:  2025-06-05 23:35:55
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{
    AppState,
    error::{MijiErrorDto, to_dto},
};
use tauri::State;

use crate::{
    dto::{PaginationParams, TodoInput, TodoListResult, TodoResponse},
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
