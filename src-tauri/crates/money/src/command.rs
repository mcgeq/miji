use common::{ApiResponse, AppState, crud::service::CrudService, paginations::PagedQuery};
use tauri::State;

use crate::{
    dto::{
        account::{
            AccountResponseWithRelations, CreateAccountRequest, UpdateAccountRequest,
            convert_to_response, tuple_to_response,
        },
        currency::{CreateCurrencyRequest, CurrencyResponse, UpdateCurrencyRequest},
        transactions::{
            CreateTransactionRequest, TransactionResponse, TransferRequest,
            UpdateTransactionRequest,
        },
    },
    services::{
        account::get_account_service,
        currency::{CurrencyFilter, get_currency_service},
        transaction::{TransactionFilter, get_transaction_service},
    },
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

// ============================================================================
// start 货币
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
// end 货币
// ============================================================================

// ============================================================================
// start 账户相关
// 获取单个账户（基本响应）
#[tauri::command]
pub async fn get_account(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service
            .get_account_with_relations(&state.db, id)
            .await
            .map(tuple_to_response),
    ))
}

// 获取单个账户（带完整关系信息）
#[tauri::command]
pub async fn get_account_with_relations(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    get_account(state, id).await
}

// 创建账户
#[tauri::command]
pub async fn create_account(
    state: State<'_, AppState>,
    data: CreateAccountRequest,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();
    let db = &state.db;

    // 先创建账户，然后获取完整信息
    let result = match service.base().create(db, data).await {
        Ok(created_account) => service
            .get_account_with_relations(db, created_account.serial_num)
            .await
            .map(tuple_to_response),
        Err(e) => Err(e),
    };

    Ok(ApiResponse::from_result(result))
}

// 更新账户
#[tauri::command]
pub async fn update_account(
    state: State<'_, AppState>,
    id: String,
    data: UpdateAccountRequest,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();
    let db = &state.db;

    // 先更新账户，然后获取完整信息
    let result = match service.base().update(db, id.clone(), data).await {
        Ok(_) => service
            .get_account_with_relations(db, id)
            .await
            .map(tuple_to_response),
        Err(e) => Err(e),
    };

    Ok(ApiResponse::from_result(result))
}

// 删除账户
#[tauri::command]
pub async fn delete_account(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service.base().delete(&state.db, id).await,
    ))
}

// 分页获取账户列表（简化版本）
#[tauri::command]
pub async fn list_accounts_paged(
    state: State<'_, AppState>,
    query: common::paginations::PagedQuery<crate::services::account::AccountFilter>,
) -> Result<ApiResponse<common::paginations::PagedResult<AccountResponseWithRelations>>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service
            .list_accounts_paged_with_relations(&state.db, query)
            .await
            .map(convert_to_response),
    ))
}
// end 账户相关
// ============================================================================

// ============================================================================
// -- Transaction
#[tauri::command]
pub async fn create_transaction(
    state: State<'_, AppState>,
    data: CreateTransactionRequest,
) -> Result<ApiResponse<TransactionResponse>, String> {
    let service = get_transaction_service();
    let db = &state.db;

    Ok(ApiResponse::from_result(
        service
            .create(db, data)
            .await
            .map(TransactionResponse::from),
    ))
}

#[tauri::command]
pub async fn transfer(
    state: State<'_, AppState>,
    data: TransferRequest,
) -> Result<ApiResponse<(TransactionResponse, TransactionResponse)>, String> {
    let service = get_transaction_service();
    let db = &state.db;

    match service.transfer(db, data).await {
        Ok((from_tx, to_tx)) => Ok(ApiResponse::success((
            TransactionResponse::from(from_tx),
            TransactionResponse::from(to_tx),
        ))),
        Err(e) => Ok(ApiResponse::from_error(e)),
    }
}

// 获取单个交易（按 ID）
#[tauri::command]
pub async fn get_transaction(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<TransactionResponse>, String> {
    let service = get_transaction_service();
    let db = &state.db;

    Ok(ApiResponse::from_result(
        service
            .get_by_id(db, id)
            .await
            .map(TransactionResponse::from),
    ))
}

// 更新交易
#[tauri::command]
pub async fn update_transaction(
    state: State<'_, AppState>,
    id: String,
    data: UpdateTransactionRequest,
) -> Result<ApiResponse<TransactionResponse>, String> {
    let service = get_transaction_service();
    let db = &state.db;

    Ok(ApiResponse::from_result(
        service
            .update(db, id, data)
            .await
            .map(TransactionResponse::from),
    ))
}

// 删除交易
#[tauri::command]
pub async fn delete_transaction(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_transaction_service();
    let db = &state.db;

    Ok(ApiResponse::from_result(service.delete(db, id).await))
}

// 列出交易（带过滤条件）
#[tauri::command]
pub async fn list_transactions(
    state: State<'_, AppState>,
    filter: TransactionFilter,
) -> Result<ApiResponse<Vec<TransactionResponse>>, String> {
    let service = get_transaction_service();
    let db = &state.db;

    Ok(ApiResponse::from_result(
        service
            .list_with_filter(db, filter)
            .await
            .map(|models| models.into_iter().map(TransactionResponse::from).collect()),
    ))
}

// 分页列出交易
#[tauri::command]
pub async fn list_paged_transactions(
    state: State<'_, AppState>,
    query: PagedQuery<TransactionFilter>,
) -> Result<ApiResponse<PagedResult<TransactionResponse>>, String> {
    let service = get_transaction_service();
    let db = &state.db;

    Ok(ApiResponse::from_result(
        service
            .list_paged(db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged
                    .rows
                    .into_iter()
                    .map(TransactionResponse::from)
                    .collect(),
                total_count: paged.total_count as i64,
                current_page: paged.current_page as i32,
                page_size: paged.page_size as i32,
                total_pages: paged.total_pages as i32,
            }),
    ))
}
