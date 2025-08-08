use common::{ApiResponse, AppState, crud::service::CrudService, paginations::PagedQuery};
use tauri::State;

use crate::{
    dto::currency::{CreateCurrencyRequest, CurrencyResponse, UpdateCurrencyRequest},
    services::currency::{CurrencyFilter, get_currency_service},
};

// 定义分页结果结构体
#[derive(serde::Serialize)]
pub struct PagedResult<T> {
    rows: Vec<T>,
    total_count: i64,
    current_page: i32,
    page_size: i32,
    total_pages: i32,
}

// 创建货币
#[tauri::command]
pub async fn create_currency(
    state: State<'_, AppState>,
    data: CreateCurrencyRequest,
) -> Result<ApiResponse<CurrencyResponse>, String> {
    let service = get_currency_service();
    let db = &state.db;
    Ok(ApiResponse::from_result(
        service.create(db, data).await.map(CurrencyResponse::from),
    ))
}

// 获取单个货币（按 ID）
#[tauri::command]
pub async fn get_currency(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<CurrencyResponse>, String> {
    let service = get_currency_service();
    let db = &state.db;
    Ok(ApiResponse::from_result(
        service.get_by_id(db, id).await.map(CurrencyResponse::from),
    ))
}

// 更新货币
#[tauri::command]
pub async fn update_currency(
    state: State<'_, AppState>,
    id: String,
    data: UpdateCurrencyRequest,
) -> Result<ApiResponse<CurrencyResponse>, String> {
    let service = get_currency_service();
    let db = &state.db;
    Ok(ApiResponse::from_result(
        service
            .update(db, id, data)
            .await
            .map(CurrencyResponse::from),
    ))
}
// 删除货币
#[tauri::command]
pub async fn delete_currency(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_currency_service();
    let db = &state.db;
    Ok(ApiResponse::from_result(service.delete(db, id).await))
}

// 列出货币（带过滤条件）
#[tauri::command]
pub async fn list_currencies(
    state: State<'_, AppState>,
    filter: CurrencyFilter,
) -> Result<ApiResponse<Vec<CurrencyResponse>>, String> {
    let service = get_currency_service();
    let db = &state.db;
    Ok(ApiResponse::from_result(
        service
            .list_with_filter(db, filter)
            .await
            .map(|models| models.into_iter().map(CurrencyResponse::from).collect()),
    ))
}

// 分页列出货币
#[tauri::command]
pub async fn list_currencies_paged(
    state: State<'_, AppState>,
    query: PagedQuery<CurrencyFilter>,
) -> Result<ApiResponse<PagedResult<CurrencyResponse>>, String> {
    let service = get_currency_service();
    let db = &state.db;
    Ok(ApiResponse::from_result(
        service
            .list_paged(db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(CurrencyResponse::from).collect(),
                total_count: paged.total_count as i64,
                current_page: paged.current_page as i32,
                page_size: paged.page_size as i32,
                total_pages: paged.total_pages as i32,
            }),
    ))
}

#[tauri::command]
pub async fn list_account() -> String {
    eprintln!("todos list");
    "list".to_string()
}

#[tauri::command]
pub async fn list_paged_account() {
    eprintln!("todos listPaged");
}

#[tauri::command]
pub async fn create_account() {
    eprintln!("todos create");
}

#[tauri::command]
pub async fn update_account() {
    eprintln!("todos update");
}

#[tauri::command]
pub async fn delete_account() {
    eprintln!("todos delete");
}

#[tauri::command]
pub async fn list_transactions() -> String {
    eprintln!("todos list");
    "list".to_string()
}

#[tauri::command]
pub async fn list_paged_transactions() {
    eprintln!("todos listPaged");
}

#[tauri::command]
pub async fn create_transaction() {
    eprintln!("todos create");
}

#[tauri::command]
pub async fn update_transaction() {
    eprintln!("todos update");
}

#[tauri::command]
pub async fn delete_transaction() {
    eprintln!("todos delete");
}
