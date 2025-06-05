// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           handlers.rs
// Description:    About Handlers
// Create   Date:  2025-06-04 22:02:38
// Last Modified:  2025-06-05 23:01:14
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{
    AppState,
    business_code::BusinessCode,
    error::{MijiError, MijiResult},
};
use tauri::State;
use validator::Validate;

use crate::{
    dto::{
        CreateOrUpdateForm, PaginationParams, ProjectResponse, TagResponse, TodoInput,
        TodoListResult, TodoResponse,
    },
    error::TodosError,
    services::{ProjectService, TagService, TodoService},
};

pub struct TodoHandler;
pub struct TagHandler;
pub struct ProjectHandler;

impl TodoHandler {
    pub async fn list(
        pagination: PaginationParams,
        state: State<'_, AppState>,
    ) -> MijiResult<TodoListResult> {
        if let Err(e) = pagination.validate() {
            return Err(MijiError::Auth(Box::new(TodosError::Validation {
                code: BusinessCode::Unauthorized,
                message: e.to_string(),
            })));
        }
        TodoService::list(state, &pagination).await
    }

    pub async fn create(param: TodoInput, state: State<'_, AppState>) -> MijiResult<TodoResponse> {
        TodoService::create(state, param).await
    }

    pub async fn update(
        serial_num: String,
        param: TodoInput,
        state: State<'_, AppState>,
    ) -> MijiResult<TodoResponse> {
        TodoService::update(state, serial_num, param).await
    }

    pub async fn delete(
        serial_num: String,
        state: State<'_, AppState>,
    ) -> MijiResult<TodoResponse> {
        TodoService::delete(state, serial_num).await
    }
}

impl TagHandler {
    pub async fn list(
        pagination: PaginationParams,
        state: State<'_, AppState>,
    ) -> MijiResult<Vec<TagResponse>> {
        if let Err(e) = pagination.validate() {
            return Err(MijiError::Auth(Box::new(TodosError::Validation {
                code: BusinessCode::Unauthorized,
                message: e.to_string(),
            })));
        }
        TagService::list(state, &pagination).await
    }

    pub async fn create(
        param: &CreateOrUpdateForm,
        state: State<'_, AppState>,
    ) -> MijiResult<TagResponse> {
        TagService::create(state, param).await
    }

    pub async fn update(
        serial_num: String,
        param: &CreateOrUpdateForm,
        state: State<'_, AppState>,
    ) -> MijiResult<TagResponse> {
        TagService::update(state, &serial_num, param).await
    }

    pub async fn delete(serial_num: String, state: State<'_, AppState>) -> MijiResult<TagResponse> {
        TagService::delete(state, &serial_num).await
    }
}

impl ProjectHandler {
    pub async fn list(
        pagination: PaginationParams,
        state: State<'_, AppState>,
    ) -> MijiResult<Vec<ProjectResponse>> {
        if let Err(e) = pagination.validate() {
            return Err(MijiError::Auth(Box::new(TodosError::Validation {
                code: BusinessCode::Unauthorized,
                message: e.to_string(),
            })));
        }
        ProjectService::list(state, &pagination).await
    }

    pub async fn create(
        param: &CreateOrUpdateForm,
        state: State<'_, AppState>,
    ) -> MijiResult<ProjectResponse> {
        ProjectService::create(state, param).await
    }

    pub async fn update(
        serial_num: String,
        param: &CreateOrUpdateForm,
        state: State<'_, AppState>,
    ) -> MijiResult<ProjectResponse> {
        ProjectService::update(state, &serial_num, param).await
    }

    pub async fn delete(
        serial_num: String,
        state: State<'_, AppState>,
    ) -> MijiResult<ProjectResponse> {
        ProjectService::delete(state, &serial_num).await
    }
}
