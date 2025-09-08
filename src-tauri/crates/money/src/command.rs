use common::{
    ApiResponse, AppState,
    crud::service::CrudService,
    paginations::{PagedQuery, PagedResult},
};
use tauri::State;
use tracing::info;

use crate::{
    dto::{
        account::{
            AccountBalanceSummary, AccountResponseWithRelations, CreateAccountRequest,
            UpdateAccountRequest, convert_to_account, convert_to_response, tuple_to_response,
        },
        bil_reminder::{BilReminder, BilReminderCreate, BilReminderUpdate},
        budget::{Budget, BudgetCreate, BudgetUpdate},
        currency::{CreateCurrencyRequest, CurrencyResponse, UpdateCurrencyRequest},
        transactions::{
            CreateTransactionRequest, IncomeExpense, TransactionResponse, TransferRequest,
            UpdateTransactionRequest,
        },
    },
    services::{
        account::{AccountFilter, get_account_service},
        bil_reminder::{BilReminderFilters, get_bil_reminder_service},
        budget::{BudgetFilter, get_budget_service},
        currency::{CurrencyFilter, get_currency_service},
        transaction::{TransactionFilter, get_transaction_service},
    },
};

// ============================================================================
// start 货币
// 创建货币
#[tauri::command]
pub async fn currency_create(
    state: State<'_, AppState>,
    data: CreateCurrencyRequest,
) -> Result<ApiResponse<CurrencyResponse>, String> {
    let service = get_currency_service();
    Ok(ApiResponse::from_result(
        service
            .create(&state.db, data)
            .await
            .map(CurrencyResponse::from),
    ))
}

// 获取单个货币（按 ID）
#[tauri::command]
pub async fn currency_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<CurrencyResponse>, String> {
    let service = get_currency_service();
    Ok(ApiResponse::from_result(
        service
            .get_by_id(&state.db, serial_num)
            .await
            .map(CurrencyResponse::from),
    ))
}

// 更新货币
#[tauri::command]
pub async fn currency_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: UpdateCurrencyRequest,
) -> Result<ApiResponse<CurrencyResponse>, String> {
    let service = get_currency_service();
    Ok(ApiResponse::from_result(
        service
            .update(&state.db, serial_num, data)
            .await
            .map(CurrencyResponse::from),
    ))
}
// 删除货币
#[tauri::command]
pub async fn currency_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_currency_service();
    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

// 列出货币（带过滤条件）
#[tauri::command]
pub async fn currencies_list(
    state: State<'_, AppState>,
    filter: CurrencyFilter,
) -> Result<ApiResponse<Vec<CurrencyResponse>>, String> {
    let service = get_currency_service();
    Ok(ApiResponse::from_result(
        service
            .list_with_filter(&state.db, filter)
            .await
            .map(|models| models.into_iter().map(CurrencyResponse::from).collect()),
    ))
}

// 分页列出货币
#[tauri::command]
pub async fn currencies_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<CurrencyFilter>,
) -> Result<ApiResponse<PagedResult<CurrencyResponse>>, String> {
    let service = get_currency_service();
    Ok(ApiResponse::from_result(
        service
            .list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(CurrencyResponse::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}
// end 货币
// ============================================================================

// ============================================================================
// start 账户相关
// 获取单个账户（基本响应）
#[tauri::command]
pub async fn account_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service
            .get_account_with_relations(&state.db, serial_num)
            .await
            .map(tuple_to_response),
    ))
}

// 创建账户
#[tauri::command]
pub async fn account_create(
    state: State<'_, AppState>,
    data: CreateAccountRequest,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();
    // 先创建账户，然后获取完整信息
    let result = match service.create(&state.db, data).await {
        Ok(created_account) => service
            .get_account_with_relations(&state.db, created_account.serial_num)
            .await
            .map(tuple_to_response),
        Err(e) => Err(e),
    };

    Ok(ApiResponse::from_result(result))
}

// 更新账户
#[tauri::command]
pub async fn account_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: UpdateAccountRequest,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();

    // 先更新账户，然后获取完整信息
    let result = match service.update(&state.db, serial_num.clone(), data).await {
        Ok(_) => service
            .get_account_with_relations(&state.db, serial_num)
            .await
            .map(tuple_to_response),
        Err(e) => Err(e),
    };

    Ok(ApiResponse::from_result(result))
}

#[tauri::command]
pub async fn account_update_active(
    state: State<'_, AppState>,
    serial_num: String,
    is_active: bool,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service
            .update_account_active(&state.db, serial_num, is_active)
            .await
            .map(tuple_to_response),
    ))
}

// 删除账户
#[tauri::command]
pub async fn account_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

// 分页获取账户列表（简化版本）
#[tauri::command]
pub async fn account_list_paged(
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

#[tauri::command]
pub async fn account_list(
    state: State<'_, AppState>,
    filter: AccountFilter,
) -> Result<ApiResponse<Vec<AccountResponseWithRelations>>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service
            .list_with_filter(&state.db, filter)
            .await
            .map(convert_to_account),
    ))
}

#[tauri::command]
pub async fn total_assets(
    state: State<'_, AppState>,
) -> Result<ApiResponse<AccountBalanceSummary>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service.total_assets(&state.db).await,
    ))
}

// end 账户相关
// ============================================================================

// ============================================================================
// -- Transaction
#[tauri::command]
pub async fn transaction_create(
    state: State<'_, AppState>,
    data: CreateTransactionRequest,
) -> Result<ApiResponse<TransactionResponse>, String> {
    let service = get_transaction_service();
    info!("transaction_create {:?}", data);
    Ok(ApiResponse::from_result(
        service
            .trans_create_with_relations(&state.db, data)
            .await
            .map(TransactionResponse::from),
    ))
}

#[tauri::command]
pub async fn transaction_transfer_create(
    state: State<'_, AppState>,
    data: TransferRequest,
) -> Result<ApiResponse<(TransactionResponse, TransactionResponse)>, String> {
    let service = get_transaction_service();

    match service
        .trans_transfer_create_with_relations(&state.db, data)
        .await
    {
        Ok((from_tx, to_tx)) => Ok(ApiResponse::success((
            TransactionResponse::from(from_tx),
            TransactionResponse::from(to_tx),
        ))),
        Err(e) => Ok(ApiResponse::from_error(e)),
    }
}

#[tauri::command]
pub async fn transaction_query_income_and_expense(
    state: State<'_, AppState>,
    start_date: String,
    end_date: String,
) -> Result<ApiResponse<IncomeExpense>, String> {
    let service = get_transaction_service();
    Ok(ApiResponse::from_result(
        service
            .query_income_and_expense(&state.db, start_date, end_date)
            .await,
    ))
}

#[tauri::command]
pub async fn transaction_transfer_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<(TransactionResponse, TransactionResponse)>, String> {
    let service = get_transaction_service();
    match service
        .trans_transfer_delete_with_relations(&state.db, &serial_num)
        .await
    {
        Ok((from_tx, to_tx)) => Ok(ApiResponse::success((
            TransactionResponse::from(from_tx),
            TransactionResponse::from(to_tx),
        ))),
        Err(e) => Ok(ApiResponse::from_error(e)),
    }
}

#[tauri::command]
pub async fn transaction_transfer_update(
    state: State<'_, AppState>,
    serial_num: String,
    transfer: TransferRequest,
) -> Result<ApiResponse<(TransactionResponse, TransactionResponse)>, String> {
    info!(
        "transaction_transfer_update {:?} {:?}",
        serial_num, transfer
    );
    let service = get_transaction_service();
    match service
        .trans_transfer_update_with_relations(&state.db, &serial_num, transfer)
        .await
    {
        Ok((from_tx, to_tx)) => Ok(ApiResponse::success((
            TransactionResponse::from(from_tx),
            TransactionResponse::from(to_tx),
        ))),
        Err(e) => Ok(ApiResponse::from_error(e)),
    }
}

// 获取单个交易（按 ID）
#[tauri::command]
pub async fn transaction_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<TransactionResponse>, String> {
    let service = get_transaction_service();

    Ok(ApiResponse::from_result(
        service
            .trans_get_with_relations(&state.db, serial_num)
            .await
            .map(TransactionResponse::from),
    ))
}

// 更新交易
#[tauri::command]
pub async fn transaction_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: UpdateTransactionRequest,
) -> Result<ApiResponse<TransactionResponse>, String> {
    let service = get_transaction_service();

    Ok(ApiResponse::from_result(
        service
            .trans_update_with_relations(&state.db, serial_num, data)
            .await
            .map(TransactionResponse::from),
    ))
}

// 删除交易
#[tauri::command]
pub async fn transaction_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_transaction_service();

    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

// 列出交易（带过滤条件）
#[tauri::command]
pub async fn transaction_list(
    state: State<'_, AppState>,
    filter: TransactionFilter,
) -> Result<ApiResponse<Vec<TransactionResponse>>, String> {
    let service = get_transaction_service();

    Ok(ApiResponse::from_result(
        service
            .trans_list_with_relations(&state.db, filter)
            .await
            .map(|models| models.into_iter().map(TransactionResponse::from).collect()),
    ))
}

// 分页列出交易
#[tauri::command]
pub async fn transaction_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<TransactionFilter>,
) -> Result<ApiResponse<PagedResult<TransactionResponse>>, String> {
    let service = get_transaction_service();
    Ok(ApiResponse::from_result(
        service
            .trans_list_paged_with_relations(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged
                    .rows
                    .into_iter()
                    .map(TransactionResponse::from)
                    .collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}

// ============================================================================
// start 预算相关

#[tauri::command]
pub async fn budget_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<Budget>, String> {
    let service = get_budget_service();
    Ok(ApiResponse::from_result(
        service
            .get_budget_with_relations(&state.db, serial_num)
            .await
            .map(Budget::from),
    ))
}

#[tauri::command]
pub async fn budget_create(
    state: State<'_, AppState>,
    data: BudgetCreate,
) -> Result<ApiResponse<Budget>, String> {
    let service = get_budget_service();
    Ok(ApiResponse::from_result(
        service
            .create_with_relations(&state.db, data)
            .await
            .map(Budget::from),
    ))
}

#[tauri::command]
pub async fn budget_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: BudgetUpdate,
) -> Result<ApiResponse<Budget>, String> {
    let service = get_budget_service();
    Ok(ApiResponse::from_result(
        service
            .update_with_relations(&state.db, serial_num, data)
            .await
            .map(Budget::from),
    ))
}

#[tauri::command]
pub async fn budget_update_active(
    state: State<'_, AppState>,
    serial_num: String,
    is_active: bool,
) -> Result<ApiResponse<Budget>, String> {
    let service = get_budget_service();
    Ok(ApiResponse::from_result(
        service
            .budget_update_active_with_relations(&state.db, serial_num, is_active)
            .await
            .map(Budget::from),
    ))
}

#[tauri::command]
pub async fn budget_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_budget_service();

    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

#[tauri::command]
pub async fn budget_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<BudgetFilter>,
) -> Result<ApiResponse<PagedResult<Budget>>, String> {
    let service = get_budget_service();
    Ok(ApiResponse::from_result(
        service
            .budget_list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(Budget::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}
// end   预算相关
// ============================================================================

// start 提醒
// ============================================================================
#[tauri::command]
pub async fn bil_reminder_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<BilReminder>, String> {
    let service = get_bil_reminder_service();
    Ok(ApiResponse::from_result(
        service
            .get_by_id(&state.db, serial_num)
            .await
            .map(BilReminder::from),
    ))
}

#[tauri::command]
pub async fn bil_reminder_create(
    state: State<'_, AppState>,
    data: BilReminderCreate,
) -> Result<ApiResponse<BilReminder>, String> {
    let service = get_bil_reminder_service();
    Ok(ApiResponse::from_result(
        service.create(&state.db, data).await.map(BilReminder::from),
    ))
}

#[tauri::command]
pub async fn bil_reminder_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: BilReminderUpdate,
) -> Result<ApiResponse<BilReminder>, String> {
    let service = get_bil_reminder_service();
    Ok(ApiResponse::from_result(
        service
            .update(&state.db, serial_num, data)
            .await
            .map(BilReminder::from),
    ))
}

#[tauri::command]
pub async fn bil_reminder_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_bil_reminder_service();
    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

#[tauri::command]
pub async fn bil_reminder_list(
    state: State<'_, AppState>,
    filter: BilReminderFilters,
) -> Result<ApiResponse<Vec<BilReminder>>, String> {
    let service = get_bil_reminder_service();

    Ok(ApiResponse::from_result(
        service
            .list_with_filter(&state.db, filter)
            .await
            .map(|models| models.into_iter().map(BilReminder::from).collect()),
    ))
}

#[tauri::command]
pub async fn bil_reminder_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<BilReminderFilters>,
) -> Result<ApiResponse<PagedResult<BilReminder>>, String> {
    let service = get_bil_reminder_service();
    Ok(ApiResponse::from_result(
        service
            .list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(BilReminder::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}
// en
// end 提醒
// ============================================================================
