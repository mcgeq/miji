use common::{
    ApiResponse, AppState,
    crud::service::CrudService,
    paginations::{PagedQuery, PagedResult},
};
use tauri::State;
use tracing::{info, warn, error, instrument};

use crate::{
    dto::{
        account::{
            AccountBalanceSummary, AccountCreate, AccountResponseWithRelations, AccountUpdate,
        },
        bil_reminder::{BilReminder, BilReminderCreate, BilReminderUpdate},
        budget::{Budget, BudgetCreate, BudgetUpdate},
        categories::{Category, CategoryCreate, CategoryUpdate},
        currency::{CreateCurrencyRequest, CurrencyResponse, UpdateCurrencyRequest},
        family_member::FamilyMemberResponse,
        installment::{
            InstallmentCalculationRequest, InstallmentCalculationResponse, InstallmentPlanResponse,
        },
        sub_categories::{SubCategory, SubCategoryCreate, SubCategoryUpdate},
        transactions::{
            CreateTransactionRequest, IncomeExpense, TransactionResponse, TransactionStatsRequest,
            TransactionStatsResponse, TransferRequest, UpdateTransactionRequest,
        },
    },
    services::{
        account::{AccountFilter, get_account_service},
        bil_reminder::{BilReminderFilters, get_bil_reminder_service},
        budget::{BudgetFilter, get_budget_service},
        budget_trends::{BudgetTrendRequest, BudgetCategoryStats},
        categories::{CategoryFilter, get_category_service},
        currency::{CurrencyFilter, get_currency_service},
        family_member::get_family_member_service,
        installment::get_installment_service,
        sub_categories::{SubCategoryFilter, get_sub_category_service},
        transaction::{TransactionFilter, get_transaction_service},
    },
};

// ============================================================================
// start 分期付款相关
// 获取分期付款计划
#[tauri::command]
pub async fn installment_plan_get(
    state: State<'_, AppState>,
    plan_serial_num: String,
) -> Result<ApiResponse<InstallmentPlanResponse>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service
            .get_installment_plan(&state.db, &plan_serial_num)
            .await,
    ))
}

// 计算分期金额（纯计算，不涉及数据库）
#[tauri::command]
pub async fn installment_calculate(
    data: InstallmentCalculationRequest,
) -> Result<ApiResponse<InstallmentCalculationResponse>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service.calculate_installment_amount(data).await,
    ))
}

// 检查交易是否有已完成的分期付款
#[tauri::command]
pub async fn installment_has_paid(
    state: State<'_, AppState>,
    transaction_serial_num: String,
) -> Result<ApiResponse<bool>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service
            .has_paid_installments(&state.db, &transaction_serial_num)
            .await,
    ))
}
// end 分期付款相关
// ============================================================================

// ============================================================================
// start 货币
// 创建货币
#[tauri::command]
#[instrument(skip(state))]
pub async fn currency_create(
    state: State<'_, AppState>,
    data: CreateCurrencyRequest,
) -> Result<ApiResponse<CurrencyResponse>, String> {
    info!("开始创建货币");
    let service = get_currency_service();
    
    match service.create(&state.db, data.clone()).await {
        Ok(result) => {
            info!(
                currency_code = %result.code,
                currency_symbol = %result.symbol,
                "货币创建成功"
            );
            Ok(ApiResponse::from_result(Ok(CurrencyResponse::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                currency_code = %data.code,
                "货币创建失败"
            );
            Err(e.to_string())
        }
    }
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
#[instrument(skip(state), fields(currency_serial_num = %serial_num))]
pub async fn currency_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!("开始删除货币");
    let service = get_currency_service();
    
    match service.delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(
                currency_serial_num = %serial_num,
                "货币删除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                currency_serial_num = %serial_num,
                "货币删除失败"
            );
            Err(e.to_string())
        }
    }
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
            .map(AccountResponseWithRelations::from),
    ))
}

// 创建账户
#[tauri::command]
#[instrument(skip(state))]
pub async fn account_create(
    state: State<'_, AppState>,
    data: AccountCreate,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    info!(
        account_name = %data.name.clone(),
        account_type = %data.r#type.clone(),
        initial_balance = %data.initial_balance,
        "开始创建账户"
    );
    
    let service = get_account_service();

    match service.account_create(&state.db, data).await {
        Ok(result) => {
            info!(
                account_serial_num = %result.account.serial_num,
                account_name = %result.account.name,
                account_type = %result.account.r#type,
                balance = %result.account.balance,
                "账户创建成功"
            );
            Ok(ApiResponse::from_result(Ok(AccountResponseWithRelations::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                "账户创建失败"
            );
            Err(e.to_string())
        }
    }
}

// 更新账户
#[tauri::command]
pub async fn account_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: AccountUpdate,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();
    Ok(ApiResponse::from_result(
        service
            .account_update(&state.db, serial_num, data)
            .await
            .map(AccountResponseWithRelations::from),
    ))
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
            .map(AccountResponseWithRelations::from),
    ))
}

// 删除账户
#[tauri::command]
#[instrument(skip(state), fields(account_serial_num = %serial_num))]
pub async fn account_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    // 先获取账户信息用于日志
    let service = get_account_service();
    
    // 尝试获取账户信息（用于日志，但不影响删除逻辑）
    let account_info = service.get_account_with_relations(&state.db, serial_num.clone()).await.ok();
    
    if let Some(account) = &account_info {
        warn!(
            account_serial_num = %serial_num,
            account_name = %account.account.name,
            balance = %account.account.balance,
            "准备删除账户，账户当前有余额"
        );
    }
    
    match service.delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(
                account_serial_num = %serial_num,
                account_name = account_info.as_ref().map(|a| &a.account.name).unwrap_or(&"未知".to_string()),
                "账户删除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                account_serial_num = %serial_num,
                "账户删除失败"
            );
            Err(e.to_string())
        }
    }
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
            .map(|paged| PagedResult {
                rows: paged
                    .rows
                    .into_iter()
                    .map(AccountResponseWithRelations::from)
                    .collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
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
            .map(|paged| {
                paged
                    .rows
                    .into_iter()
                    .map(AccountResponseWithRelations::from)
                    .collect()
            }),
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
#[instrument(skip(state))]
pub async fn transaction_create(
    state: State<'_, AppState>,
    data: CreateTransactionRequest,
) -> Result<ApiResponse<TransactionResponse>, String> {
    info!(
        amount = %data.amount,
        transaction_type = %data.transaction_type,
        account_serial_num = %data.account_serial_num,
        category = %data.category,
        "开始创建交易记录"
    );
    
    let service = get_transaction_service();
    
    match service.trans_create_with_relations(&state.db, data).await {
        Ok(result) => {
            info!(
                transaction_serial_num = %result.transaction.serial_num,
                amount = %result.transaction.amount,
                transaction_type = %result.transaction.transaction_type,
                account_serial_num = %result.transaction.account_serial_num,
                "交易记录创建成功"
            );
            Ok(ApiResponse::from_result(Ok(TransactionResponse::from(result))))
        }
        Err(e) => {
            let error_msg = format!("交易记录创建失败: {}", e);
            error!(%error_msg);
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn transaction_transfer_create(
    state: State<'_, AppState>,
    data: TransferRequest,
) -> Result<ApiResponse<(TransactionResponse, TransactionResponse)>, String> {
    info!(
        from_account = %data.account_serial_num.clone(),
        to_account = %data.to_account_serial_num.clone(),
        amount = %data.amount.clone(),
        "开始创建转账"
    );
    
    let service = get_transaction_service();

    match service
        .trans_transfer_create_with_relations(&state.db, data.clone())
        .await
    {
        Ok((from_tx, to_tx)) => {
            info!(
                from_transaction_serial_num = %from_tx.transaction.serial_num,
                to_transaction_serial_num = %to_tx.transaction.serial_num,
                amount = %from_tx.transaction.amount,
                "转账创建成功"
            );
            Ok(ApiResponse::success((
                TransactionResponse::from(from_tx),
                TransactionResponse::from(to_tx),
            )))
        }
        Err(e) => {
            error!(
                error = %e,
                from_account = %data.account_serial_num,
                to_account = %data.to_account_serial_num,
                "转账创建失败"
            );
            Ok(ApiResponse::from_error(e))
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn transaction_query_income_and_expense(
    state: State<'_, AppState>,
    start_date: String,
    end_date: String,
) -> Result<ApiResponse<IncomeExpense>, String> {
    info!(
        start_date = %start_date,
        end_date = %end_date,
        "查询收支统计"
    );
    
    let service = get_transaction_service();
    
    match service
        .query_income_and_expense(&state.db, start_date.clone(), end_date.clone())
        .await
    {
        Ok(result) => {
            info!(
                income_total = %result.income.total,
                expense_total = %result.expense.total,
                "查询收支统计成功"
            );
            Ok(ApiResponse::from_result(Ok(result)))
        }
        Err(e) => {
            error!(
                error = %e,
                start_date = %start_date,
                end_date = %end_date,
                "查询收支统计失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(transaction_serial_num = %serial_num))]
pub async fn transaction_transfer_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<(TransactionResponse, TransactionResponse)>, String> {
    info!(
        transaction_serial_num = %serial_num,
        "开始删除转账"
    );
    
    let service = get_transaction_service();
    
    match service
        .trans_transfer_delete_with_relations(&state.db, &serial_num)
        .await
    {
        Ok((from_tx, to_tx)) => {
            info!(
                from_transaction_serial_num = %from_tx.transaction.serial_num,
                to_transaction_serial_num = %to_tx.transaction.serial_num,
                "转账删除成功"
            );
            Ok(ApiResponse::success((
                TransactionResponse::from(from_tx),
                TransactionResponse::from(to_tx),
            )))
        }
        Err(e) => {
            error!(
                error = %e,
                transaction_serial_num = %serial_num,
                "转账删除失败"
            );
            Ok(ApiResponse::from_error(e))
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(transaction_serial_num = %serial_num))]
pub async fn transaction_transfer_update(
    state: State<'_, AppState>,
    serial_num: String,
    transfer: TransferRequest,
) -> Result<ApiResponse<(TransactionResponse, TransactionResponse)>, String> {
    info!(
        transaction_serial_num = %serial_num,
        amount = %transfer.amount.clone(),
        "开始更新转账"
    );
    
    let service = get_transaction_service();
    
    match service
        .trans_transfer_update_with_relations(&state.db, &serial_num, transfer)
        .await
    {
        Ok((from_tx, to_tx)) => {
            info!(
                from_transaction_serial_num = %from_tx.transaction.serial_num,
                to_transaction_serial_num = %to_tx.transaction.serial_num,
                amount = %from_tx.transaction.amount,
                "转账更新成功"
            );
            Ok(ApiResponse::success((
                TransactionResponse::from(from_tx),
                TransactionResponse::from(to_tx),
            )))
        }
        Err(e) => {
            error!(
                error = %e,
                transaction_serial_num = %serial_num,
                "转账更新失败"
            );
            Ok(ApiResponse::from_error(e))
        }
    }
}

// 获取单个交易（按 ID）
#[tauri::command]
#[instrument(skip(state), fields(transaction_serial_num = %serial_num))]
pub async fn transaction_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<TransactionResponse>, String> {
    let service = get_transaction_service();

    match service
        .trans_get_with_relations(&state.db, serial_num.clone())
        .await
    {
        Ok(result) => {
            info!(
                transaction_serial_num = %result.transaction.serial_num,
                amount = %result.transaction.amount,
                transaction_type = %result.transaction.transaction_type,
                "获取交易成功"
            );
            Ok(ApiResponse::from_result(Ok(TransactionResponse::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                transaction_serial_num = %serial_num,
                "获取交易失败"
            );
            Err(e.to_string())
        }
    }
}

// 更新交易
#[tauri::command]
#[instrument(skip(state), fields(transaction_serial_num = %serial_num))]
pub async fn transaction_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: UpdateTransactionRequest,
) -> Result<ApiResponse<TransactionResponse>, String> {
    info!(
        transaction_serial_num = %serial_num,
        "开始更新交易"
    );
    
    let service = get_transaction_service();

    match service
        .trans_update_with_relations(&state.db, serial_num.clone(), data)
        .await
    {
        Ok(result) => {
            info!(
                transaction_serial_num = %result.transaction.serial_num,
                amount = %result.transaction.amount,
                transaction_type = %result.transaction.transaction_type,
                "交易更新成功"
            );
            Ok(ApiResponse::from_result(Ok(TransactionResponse::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                transaction_serial_num = %serial_num,
                "交易更新失败"
            );
            Err(e.to_string())
        }
    }
}

// 删除交易
#[tauri::command]
#[instrument(skip(state), fields(transaction_serial_num = %serial_num))]
pub async fn transaction_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        transaction_serial_num = %serial_num,
        "开始删除交易"
    );
    
    let service = get_transaction_service();

    match service.delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(
                transaction_serial_num = %serial_num,
                "交易删除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                transaction_serial_num = %serial_num,
                "交易删除失败"
            );
            Err(e.to_string())
        }
    }
}

// 列出交易（带过滤条件）
#[tauri::command]
#[instrument(skip(state))]
pub async fn transaction_list(
    state: State<'_, AppState>,
    filter: TransactionFilter,
) -> Result<ApiResponse<Vec<TransactionResponse>>, String> {
    let service = get_transaction_service();

    match service
        .trans_list_with_relations(&state.db, filter)
        .await
    {
        Ok(transactions) => {
            info!(
                count = transactions.len(),
                "列出交易成功"
            );
            Ok(ApiResponse::from_result(Ok(transactions.into_iter().map(TransactionResponse::from).collect())))
        }
        Err(e) => {
            error!(
                error = %e,
                "列出交易失败"
            );
            Err(e.to_string())
        }
    }
}

// 分页列出交易
#[tauri::command]
#[instrument(skip(state))]
pub async fn transaction_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<TransactionFilter>,
) -> Result<ApiResponse<PagedResult<TransactionResponse>>, String> {
    let service = get_transaction_service();
    
    match service
        .trans_list_paged_with_relations(&state.db, query)
        .await
    {
        Ok(paged) => {
            info!(
                total_count = paged.total_count,
                current_page = paged.current_page,
                page_size = paged.page_size,
                "分页列出交易成功"
            );
            Ok(ApiResponse::from_result(Ok(PagedResult {
                rows: paged
                    .rows
                    .into_iter()
                    .map(TransactionResponse::from)
                    .collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            })))
        }
        Err(e) => {
            error!(
                error = %e,
                "分页列出交易失败"
            );
            Err(e.to_string())
        }
    }
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

#[tauri::command]
pub async fn budget_overview_calculate(
    state: State<'_, AppState>,
    request: crate::services::budget_overview::BudgetOverviewRequest,
) -> Result<ApiResponse<crate::services::budget_overview::BudgetOverviewSummary>, String> {
    info!("收到预算总览计算请求: {:?}", request);
    
    match crate::services::budget_overview::BudgetOverviewService::calculate_overview(&state.db, request).await {
        Ok(result) => {
            info!("预算总览计算成功: {:?}", result);
            Ok(ApiResponse::from_result(Ok(result)))
        },
        Err(e) => {
            warn!("预算总览计算失败: {}", e);
            Ok(ApiResponse::from_result(Err(e)))
        }
    }
}

#[tauri::command]
pub async fn budget_overview_by_type(
    state: State<'_, AppState>,
    request: crate::services::budget_overview::BudgetOverviewRequest,
) -> Result<ApiResponse<std::collections::HashMap<String, crate::services::budget_overview::BudgetOverviewSummary>>, String> {
    Ok(ApiResponse::from_result(
        crate::services::budget_overview::BudgetOverviewService::calculate_by_budget_type(&state.db, request).await,
    ))
}

#[tauri::command]
pub async fn budget_overview_by_scope(
    state: State<'_, AppState>,
    request: crate::services::budget_overview::BudgetOverviewRequest,
) -> Result<ApiResponse<std::collections::HashMap<String, crate::services::budget_overview::BudgetOverviewSummary>>, String> {
    Ok(ApiResponse::from_result(
        crate::services::budget_overview::BudgetOverviewService::calculate_by_scope_type(&state.db, request).await,
    ))
}
#[tauri::command]
pub async fn budget_trends_get(
    state: State<'_, AppState>,
    request: BudgetTrendRequest,
) -> Result<ApiResponse<Vec<crate::services::budget_trends::BudgetTrendData>>, String> {
    info!("收到预算趋势分析请求: {:?}", request);
    
    match crate::services::budget_trends::BudgetTrendService::get_budget_trends(&state.db, request).await {
        Ok(result) => {
            info!("预算趋势分析成功: {} 个数据点", result.len() as usize);
            Ok(ApiResponse::from_result(Ok(result)))
        },
        Err(e) => {
            error!("预算趋势分析失败: {}", e);
            Err(format!("预算趋势分析失败: {}", e))
        }
    }
}

#[tauri::command]
pub async fn budget_category_stats_get(
    state: State<'_, AppState>,
    base_currency: String,
    include_inactive: Option<bool>,
) -> Result<ApiResponse<Vec<BudgetCategoryStats>>, String> {
    info!("收到预算分类统计请求: currency={}, include_inactive={:?}", base_currency, include_inactive);
    
    match crate::services::budget_trends::BudgetTrendService::get_budget_category_stats(&state.db, base_currency, include_inactive).await {
        Ok(result) => {
            info!("预算分类统计成功: {} 个分类", result.len() as usize);
            Ok(ApiResponse::from_result(Ok(result)))
        },
        Err(e) => {
            error!("预算分类统计失败: {}", e);
            Err(format!("预算分类统计失败: {}", e))
        }
    }
}
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
    info!("bil_reminder_create {:?}", data);
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

// Category
#[tauri::command]
pub async fn category_get(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<Category>, String> {
    let service = get_category_service();
    Ok(ApiResponse::from_result(
        service
            .category_get(&state.db, id)
            .await
            .map(Category::from),
    ))
}

#[tauri::command]
pub async fn category_create(
    state: State<'_, AppState>,
    data: CategoryCreate,
) -> Result<ApiResponse<Category>, String> {
    let service = get_category_service();
    Ok(ApiResponse::from_result(
        service
            .category_create(&state.db, data)
            .await
            .map(Category::from),
    ))
}

#[tauri::command]
pub async fn category_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: CategoryUpdate,
) -> Result<ApiResponse<Category>, String> {
    let service = get_category_service();
    Ok(ApiResponse::from_result(
        service
            .category_update(&state.db, serial_num, data)
            .await
            .map(Category::from),
    ))
}

#[tauri::command]
pub async fn category_delete(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_category_service();
    Ok(ApiResponse::from_result(
        service.category_delete(&state.db, id).await,
    ))
}

#[tauri::command]
pub async fn category_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<Category>>, String> {
    let service = get_category_service();
    Ok(ApiResponse::from_result(
        service
            .category_list(&state.db)
            .await
            .map(|models| models.into_iter().map(Category::from).collect()),
    ))
}

#[tauri::command]
pub async fn category_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<CategoryFilter>,
) -> Result<ApiResponse<PagedResult<Category>>, String> {
    let service = get_category_service();
    Ok(ApiResponse::from_result(
        service
            .category_list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(Category::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}

//

// Sub Category Start
#[tauri::command]
pub async fn sub_category_get(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<SubCategory>, String> {
    let service = get_sub_category_service();
    Ok(ApiResponse::from_result(
        service
            .sub_category_get(&state.db, id)
            .await
            .map(SubCategory::from),
    ))
}

#[tauri::command]
pub async fn sub_category_create(
    state: State<'_, AppState>,
    data: SubCategoryCreate,
) -> Result<ApiResponse<SubCategory>, String> {
    let service = get_sub_category_service();
    Ok(ApiResponse::from_result(
        service
            .sub_category_create(&state.db, data)
            .await
            .map(SubCategory::from),
    ))
}

#[tauri::command]
pub async fn sub_category_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: SubCategoryUpdate,
) -> Result<ApiResponse<SubCategory>, String> {
    let service = get_sub_category_service();
    Ok(ApiResponse::from_result(
        service
            .sub_category_update(&state.db, serial_num, data)
            .await
            .map(SubCategory::from),
    ))
}

#[tauri::command]
pub async fn sub_category_delete(
    state: State<'_, AppState>,
    id: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_sub_category_service();
    Ok(ApiResponse::from_result(
        service.sub_category_delete(&state.db, id).await,
    ))
}

#[tauri::command]
pub async fn sub_category_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<SubCategory>>, String> {
    let service = get_sub_category_service();
    Ok(ApiResponse::from_result(
        service
            .sub_category_list(&state.db)
            .await
            .map(|models| models.into_iter().map(SubCategory::from).collect()),
    ))
}

#[tauri::command]
pub async fn sub_category_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<SubCategoryFilter>,
) -> Result<ApiResponse<PagedResult<SubCategory>>, String> {
    let service = get_sub_category_service();
    Ok(ApiResponse::from_result(
        service
            .sub_category_list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(SubCategory::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}

// Sub Category End

#[tauri::command]
pub async fn family_member_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<FamilyMemberResponse>>, String> {
    let service = get_family_member_service();
    Ok(ApiResponse::from_result(
        service
            .family_member_list(&state.db)
            .await
            .map(|models| models.into_iter().map(FamilyMemberResponse::from).collect()),
    ))
}

// ============================================================================
// Transaction Statistics API
// 获取交易统计数据
#[tauri::command]
pub async fn transaction_get_stats(
    state: State<'_, AppState>,
    request: TransactionStatsRequest,
) -> Result<ApiResponse<TransactionStatsResponse>, String> {
    let service = get_transaction_service();
    Ok(ApiResponse::from_result(
        service.get_transaction_stats(&state.db, request).await,
    ))
}
