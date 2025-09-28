use common::{
    ApiResponse, AppState,
    paginations::{PagedQuery, PagedResult},
};
use entity::todo::Status;
use tauri::State;

use crate::{
    dto::todo::{Todo, TodoCreate, TodoUpdate},
    service::todo::{TodosFilter, get_todos_service},
};

// ========================== Start ==========================
// Period Records
#[tauri::command]
pub async fn todo_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<Todo>, String> {
    let service = get_todos_service();
    Ok(ApiResponse::from_result(
        service
            .todo_get(&state.db, serial_num)
            .await
            .map(Todo::from),
    ))
}

#[tauri::command]
pub async fn todo_create(
    state: State<'_, AppState>,
    data: TodoCreate,
) -> Result<ApiResponse<Todo>, String> {
    let service = get_todos_service();
    Ok(ApiResponse::from_result(
        service.todo_create(&state.db, data).await.map(Todo::from),
    ))
}

#[tauri::command]
pub async fn todo_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: TodoUpdate,
) -> Result<ApiResponse<Todo>, String> {
    let service = get_todos_service();
    Ok(ApiResponse::from_result(
        service
            .todo_update(&state.db, serial_num, data)
            .await
            .map(Todo::from),
    ))
}

#[tauri::command]
pub async fn todo_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_todos_service();
    Ok(ApiResponse::from_result(
        service.todo_delete(&state.db, serial_num).await,
    ))
}

#[tauri::command]
pub async fn todo_toggle(
    state: State<'_, AppState>,
    serial_num: String,
    status: Status,
) -> Result<ApiResponse<Todo>, String> {
    let service = get_todos_service();
    Ok(ApiResponse::from_result(
        service
            .todo_toggle(&state.db, serial_num, status)
            .await
            .map(Todo::from),
    ))
}

#[tauri::command]
pub async fn todo_list(
    state: State<'_, AppState>,
    filter: TodosFilter,
) -> Result<ApiResponse<Vec<Todo>>, String> {
    let service = get_todos_service();
    Ok(ApiResponse::from_result(
        service
            .todo_list_with_filter(&state.db, filter)
            .await
            .map(|paged| paged.into_iter().map(Todo::from).collect()),
    ))
}

#[tauri::command]
pub async fn todo_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<TodosFilter>,
) -> Result<ApiResponse<PagedResult<Todo>>, String> {
    let service = get_todos_service();
    Ok(ApiResponse::from_result(
        service
            .todo_list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(Todo::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}
