use common::{
    ApiResponse, AppState,
    paginations::{PagedQuery, PagedResult},
};
use entity::todo::Status;
use tauri::State;
use tracing::{info, error, instrument};

use crate::{
    dto::todo::{Todo, TodoCreate, TodoUpdate},
    service::todo::{TodosFilter, get_todos_service},
};

// ========================== Start ==========================
// Period Records
#[tauri::command]
#[instrument(skip(state), fields(todo_serial_num = %serial_num))]
pub async fn todo_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<Todo>, String> {
    let service = get_todos_service();
    
    match service.todo_get(&state.db, serial_num.clone()).await {
        Ok(result) => {
            info!(
                todo_serial_num = %result.serial_num,
                "获取待办事项成功"
            );
            Ok(ApiResponse::from_result(Ok(Todo::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %serial_num,
                "获取待办事项失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_create(
    state: State<'_, AppState>,
    data: TodoCreate,
) -> Result<ApiResponse<Todo>, String> {
    info!(
        title = %data.core.title.clone(),
        "开始创建待办事项"
    );
    
    let service = get_todos_service();
    
    match service.todo_create(&state.db, data).await {
        Ok(result) => {
            info!(
                todo_serial_num = %result.serial_num,
                title = %result.title,
                "待办事项创建成功"
            );
            Ok(ApiResponse::from_result(Ok(Todo::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                "待办事项创建失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(todo_serial_num = %serial_num))]
pub async fn todo_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: TodoUpdate,
) -> Result<ApiResponse<Todo>, String> {
    info!(
        todo_serial_num = %serial_num,
        "开始更新待办事项"
    );
    
    let service = get_todos_service();
    
    match service.todo_update(&state.db, serial_num.clone(), data).await {
        Ok(result) => {
            info!(
                todo_serial_num = %result.serial_num,
                title = %result.title,
                "待办事项更新成功"
            );
            Ok(ApiResponse::from_result(Ok(Todo::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %serial_num,
                "待办事项更新失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(todo_serial_num = %serial_num))]
pub async fn todo_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        todo_serial_num = %serial_num,
        "开始删除待办事项"
    );
    
    let service = get_todos_service();
    
    match service.todo_delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(
                todo_serial_num = %serial_num,
                "待办事项删除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %serial_num,
                "待办事项删除失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(todo_serial_num = %serial_num, status = ?status))]
pub async fn todo_toggle(
    state: State<'_, AppState>,
    serial_num: String,
    status: Status,
) -> Result<ApiResponse<Todo>, String> {
    info!(
        todo_serial_num = %serial_num,
        status = ?status,
        "开始切换待办事项状态"
    );
    
    let service = get_todos_service();
    
    match service.todo_toggle(&state.db, serial_num.clone(), status).await {
        Ok(result) => {
            info!(
                todo_serial_num = %result.serial_num,
                title = %result.title,
                "待办事项状态切换成功"
            );
            Ok(ApiResponse::from_result(Ok(Todo::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %serial_num,
                "待办事项状态切换失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_list(
    state: State<'_, AppState>,
    filter: TodosFilter,
) -> Result<ApiResponse<Vec<Todo>>, String> {
    let service = get_todos_service();
    
    match service.todo_list_with_filter(&state.db, filter).await {
        Ok(todos) => {
            info!(
                count = todos.len(),
                "列出待办事项成功"
            );
            Ok(ApiResponse::from_result(Ok(todos.into_iter().map(Todo::from).collect())))
        }
        Err(e) => {
            error!(
                error = %e,
                "列出待办事项失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<TodosFilter>,
) -> Result<ApiResponse<PagedResult<Todo>>, String> {
    let service = get_todos_service();
    
    match service.todo_list_paged(&state.db, query).await {
        Ok(paged) => {
            info!(
                total_count = paged.total_count,
                current_page = paged.current_page,
                page_size = paged.page_size,
                "分页列出待办事项成功"
            );
            Ok(ApiResponse::from_result(Ok(PagedResult {
                rows: paged.rows.into_iter().map(Todo::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            })))
        }
        Err(e) => {
            error!(
                error = %e,
                "分页列出待办事项失败"
            );
            Err(e.to_string())
        }
    }
}
