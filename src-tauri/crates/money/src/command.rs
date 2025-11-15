use common::{
    ApiResponse, AppState,
    crud::service::CrudService,
    paginations::{PagedQuery, PagedResult},
};
use tauri::State;
use tracing::{error, info, instrument, warn};

use crate::{
    dto::{
        account::{
            AccountBalanceSummary, AccountCreate, AccountResponseWithRelations, AccountUpdate,
        },
        bil_reminder::{BilReminder, BilReminderCreate, BilReminderUpdate},
        budget::{Budget, BudgetCreate, BudgetUpdate},
        categories::{Category, CategoryCreate, CategoryUpdate},
        currency::{CreateCurrencyRequest, CurrencyResponse, UpdateCurrencyRequest},
        debt_relations::{DebtGraph, DebtRelationResponse, DebtStats, MemberDebtSummary},
        family_ledger::{
            FamilyLedgerCreate, FamilyLedgerDetailResponse, FamilyLedgerResponse, FamilyLedgerStats, FamilyLedgerUpdate,
        },
        family_ledger_account::{FamilyLedgerAccountCreate, FamilyLedgerAccountResponse},
        family_ledger_member::{FamilyLedgerMemberCreate, FamilyLedgerMemberResponse},
        family_ledger_transaction::{
            FamilyLedgerTransactionCreate, FamilyLedgerTransactionFilter,
            FamilyLedgerTransactionResponse, FamilyLedgerTransactionUpdate,
        },
        family_member::{FamilyMemberCreate, FamilyMemberResponse, FamilyMemberUpdate},
        installment::{
            InstallmentCalculationRequest, InstallmentCalculationResponse, InstallmentPlanResponse,
        },
        settlement_records::{SettlementRecordResponse, SettlementStats, SettlementSuggestion},
        split_records::{
            SplitRecordConfirm, SplitRecordCreate, SplitRecordPayment, SplitRecordResponse,
            SplitRecordStats,
        },
        split_rules::{SplitRuleCreate, SplitRuleResponse, SplitRuleUpdate},
        sub_categories::{SubCategory, SubCategoryCreate, SubCategoryUpdate},
        transactions::{
            CreateTransactionRequest, IncomeExpense, TransactionResponse, TransactionStatsRequest,
            TransactionStatsResponse, TransferRequest, UpdateTransactionRequest,
        },
    },
    services::{
        account::{AccountFilter, AccountService},
        bil_reminder::{BilReminderFilters, BilReminderService},
        budget::{BudgetFilter, BudgetService},
        budget_trends::{BudgetCategoryStats, BudgetTrendData, BudgetTrendRequest},
        categories::{CategoryFilter, CategoryService},
        currency::{CurrencyFilter, get_currency_service},
        debt_relations::DebtRelationsService,
        family_ledger::FamilyLedgerService,
        family_ledger_account::FamilyLedgerAccountService,
        family_ledger_member::FamilyLedgerMemberService,
        family_ledger_transaction::FamilyLedgerTransactionService,
        family_member::FamilyMemberService,
        family_statistics::FamilyStatisticsService,
        installment::InstallmentService,
        settlement_records::SettlementRecordsService,
        split_records::SplitRecordsService,
        split_rules::SplitRulesService,
        sub_categories::{SubCategoryFilter, SubCategoryService},
        transaction::{TransactionFilter, TransactionService},
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
    let service = InstallmentService::default();
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
    let service = InstallmentService::default();
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
    let service = InstallmentService::default();
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
    let service = AccountService::default();
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

    let service = AccountService::default();

    match service.account_create(&state.db, data).await {
        Ok(result) => {
            info!(
                account_serial_num = %result.account.serial_num,
                account_name = %result.account.name,
                account_type = %result.account.r#type,
                balance = %result.account.balance,
                "账户创建成功"
            );
            Ok(ApiResponse::from_result(Ok(
                AccountResponseWithRelations::from(result),
            )))
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
    let service = AccountService::default();
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
    let service = AccountService::default();
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
    let service = AccountService::default();

    // 尝试获取账户信息（用于日志，但不影响删除逻辑）
    let account_info = service
        .get_account_with_relations(&state.db, serial_num.clone())
        .await
        .ok();

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
    let service = AccountService::default();
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
    let service = AccountService::default();
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
    let service = AccountService::default();
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

    let service = TransactionService::default();

    match service.trans_create_with_relations(&state.db, data).await {
        Ok(result) => {
            info!(
                transaction_serial_num = %result.transaction.serial_num,
                amount = %result.transaction.amount,
                transaction_type = %result.transaction.transaction_type,
                account_serial_num = %result.transaction.account_serial_num,
                "交易记录创建成功"
            );
            Ok(ApiResponse::from_result(Ok(TransactionResponse::from(
                result,
            ))))
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

    let service = TransactionService::default();

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

    let service = TransactionService::default();

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

    let service = TransactionService::default();

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

    let service = TransactionService::default();

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
    let service = TransactionService::default();

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
            Ok(ApiResponse::from_result(Ok(TransactionResponse::from(
                result,
            ))))
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

    let service = TransactionService::default();

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
            Ok(ApiResponse::from_result(Ok(TransactionResponse::from(
                result,
            ))))
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

    let service = TransactionService::default();

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
    let service = TransactionService::default();

    match service.trans_list_with_relations(&state.db, filter).await {
        Ok(transactions) => {
            info!(count = transactions.len(), "列出交易成功");
            Ok(ApiResponse::from_result(Ok(transactions
                .into_iter()
                .map(TransactionResponse::from)
                .collect())))
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
    let service = TransactionService::default();

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
    let service = BudgetService::default();
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
    let service = BudgetService::default();
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
    let service = BudgetService::default();
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
    let service = BudgetService::default();
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
    let service = BudgetService::default();

    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

#[tauri::command]
pub async fn budget_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<BudgetFilter>,
) -> Result<ApiResponse<PagedResult<Budget>>, String> {
    let service = BudgetService::default();
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

    match crate::services::budget_overview::BudgetOverviewService::calculate_overview(
        &state.db, request,
    )
    .await
    {
        Ok(result) => {
            info!("预算总览计算成功: {:?}", result);
            Ok(ApiResponse::from_result(Ok(result)))
        }
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
) -> Result<
    ApiResponse<
        std::collections::HashMap<String, crate::services::budget_overview::BudgetOverviewSummary>,
    >,
    String,
> {
    Ok(ApiResponse::from_result(
        crate::services::budget_overview::BudgetOverviewService::calculate_by_budget_type(
            &state.db, request,
        )
        .await,
    ))
}

#[tauri::command]
pub async fn budget_overview_by_scope(
    state: State<'_, AppState>,
    request: crate::services::budget_overview::BudgetOverviewRequest,
) -> Result<
    ApiResponse<
        std::collections::HashMap<String, crate::services::budget_overview::BudgetOverviewSummary>,
    >,
    String,
> {
    Ok(ApiResponse::from_result(
        crate::services::budget_overview::BudgetOverviewService::calculate_by_scope_type(
            &state.db, request,
        )
        .await,
    ))
}
#[tauri::command]
pub async fn budget_trends_get(
    state: State<'_, AppState>,
    request: BudgetTrendRequest,
) -> Result<ApiResponse<Vec<BudgetTrendData>>, String> {
    info!("收到预算趋势分析请求: {:?}", request);

    match crate::services::budget_trends::BudgetTrendService::get_budget_trends(&state.db, request)
        .await
    {
        Ok(result) => {
            info!("预算趋势分析成功: {} 个数据点", result.len());
            Ok(ApiResponse::from_result(Ok(result)))
        }
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
    info!(
        "收到预算分类统计请求: currency={}, include_inactive={:?}",
        base_currency, include_inactive
    );

    match crate::services::budget_trends::BudgetTrendService::get_budget_category_stats(
        &state.db,
        base_currency,
        include_inactive,
    )
    .await
    {
        Ok(result) => {
            info!("预算分类统计成功: {} 个分类", result.len());
            Ok(ApiResponse::from_result(Ok(result)))
        }
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
    let service = BilReminderService::default();
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
    let service = BilReminderService::default();
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
    let service = BilReminderService::default();
    Ok(ApiResponse::from_result(
        service
            .update(&state.db, serial_num, data)
            .await
            .map(BilReminder::from),
    ))
}

#[tauri::command]
pub async fn bil_reminder_update_active(
    state: State<'_, AppState>,
    serial_num: String,
    is_active: bool,
) -> Result<ApiResponse<BilReminder>, String> {
    let service = BilReminderService::default();
    Ok(ApiResponse::from_result(
        service
            .update_is_paid(&state.db, serial_num, is_active)
            .await
            .map(BilReminder::from),
    ))
}

#[tauri::command]
pub async fn bil_reminder_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = BilReminderService::default();
    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

#[tauri::command]
pub async fn bil_reminder_list(
    state: State<'_, AppState>,
    filter: BilReminderFilters,
) -> Result<ApiResponse<Vec<BilReminder>>, String> {
    let service = BilReminderService::default();

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
    let service = BilReminderService::default();
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
    let service = CategoryService::default();
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
    let service = CategoryService::default();
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
    let service = CategoryService::default();
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
    let service = CategoryService::default();
    Ok(ApiResponse::from_result(
        service.category_delete(&state.db, id).await,
    ))
}

#[tauri::command]
pub async fn category_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<Category>>, String> {
    let service = CategoryService::default();
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
    let service = CategoryService::default();
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
    let service = SubCategoryService::default();
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
    let service = SubCategoryService::default();
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
    let service = SubCategoryService::default();
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
    let service = SubCategoryService::default();
    Ok(ApiResponse::from_result(
        service.sub_category_delete(&state.db, id).await,
    ))
}

#[tauri::command]
pub async fn sub_category_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<SubCategory>>, String> {
    let service = SubCategoryService::default();
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
    let service = SubCategoryService::default();
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

// ============================================================================
// Family Member API

/// 获取家庭成员列表
#[tauri::command]
pub async fn family_member_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<FamilyMemberResponse>>, String> {
    let service = FamilyMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .family_member_list(&state.db)
            .await
            .map(|models| models.into_iter().map(FamilyMemberResponse::from).collect()),
    ))
}

/// 获取家庭成员详情
#[tauri::command]
pub async fn family_member_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<FamilyMemberResponse>, String> {
    let service = FamilyMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .get_by_id(&state.db, serial_num)
            .await
            .map(FamilyMemberResponse::from),
    ))
}

/// 创建家庭成员
#[tauri::command]
pub async fn family_member_create(
    state: State<'_, AppState>,
    data: FamilyMemberCreate,
) -> Result<ApiResponse<FamilyMemberResponse>, String> {
    let service = FamilyMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .create(&state.db, data)
            .await
            .map(FamilyMemberResponse::from),
    ))
}

/// 更新家庭成员
#[tauri::command]
pub async fn family_member_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: FamilyMemberUpdate,
) -> Result<ApiResponse<FamilyMemberResponse>, String> {
    let service = FamilyMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .update(&state.db, serial_num, data)
            .await
            .map(FamilyMemberResponse::from),
    ))
}

/// 删除家庭成员
#[tauri::command]
pub async fn family_member_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = FamilyMemberService::default();
    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

// ============================================================================
// Family Ledger Member API

/// 获取所有账本成员关联
#[tauri::command]
pub async fn family_ledger_member_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<FamilyLedgerMemberResponse>>, String> {
    let service = FamilyLedgerMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .list(&state.db)
            .await
            .map(|models| models.into_iter().map(FamilyLedgerMemberResponse::from).collect()),
    ))
}

/// 根据账本ID获取成员关联
#[tauri::command]
pub async fn family_ledger_member_list_by_ledger(
    state: State<'_, AppState>,
    ledger_serial_num: String,
) -> Result<ApiResponse<Vec<FamilyLedgerMemberResponse>>, String> {
    let service = FamilyLedgerMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .list_by_ledger(&state.db, &ledger_serial_num)
            .await
            .map(|models| models.into_iter().map(FamilyLedgerMemberResponse::from).collect()),
    ))
}

/// 根据成员ID获取账本关联
#[tauri::command]
pub async fn family_ledger_member_list_by_member(
    state: State<'_, AppState>,
    member_serial_num: String,
) -> Result<ApiResponse<Vec<FamilyLedgerMemberResponse>>, String> {
    let service = FamilyLedgerMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .list_by_member(&state.db, &member_serial_num)
            .await
            .map(|models| models.into_iter().map(FamilyLedgerMemberResponse::from).collect()),
    ))
}

/// 创建账本成员关联
#[tauri::command]
pub async fn family_ledger_member_create(
    state: State<'_, AppState>,
    data: FamilyLedgerMemberCreate,
) -> Result<ApiResponse<FamilyLedgerMemberResponse>, String> {
    let service = FamilyLedgerMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .create(&state.db, data.family_ledger_serial_num, data.family_member_serial_num)
            .await
            .map(FamilyLedgerMemberResponse::from),
    ))
}

/// 删除账本成员关联
#[tauri::command]
pub async fn family_ledger_member_delete(
    state: State<'_, AppState>,
    ledger_serial_num: String,
    member_serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = FamilyLedgerMemberService::default();
    Ok(ApiResponse::from_result(
        service
            .delete(&state.db, &ledger_serial_num, &member_serial_num)
            .await,
    ))
}

// ============================================================================
// Family Ledger Account API

/// 获取所有账本账户关联
#[tauri::command]
pub async fn family_ledger_account_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<FamilyLedgerAccountResponse>>, String> {
    let service = FamilyLedgerAccountService::default();
    Ok(ApiResponse::from_result(
        service
            .list(&state.db)
            .await
            .map(|models| models.into_iter().map(FamilyLedgerAccountResponse::from).collect()),
    ))
}

/// 根据账本ID获取账户关联
#[tauri::command]
pub async fn family_ledger_account_list_by_ledger(
    state: State<'_, AppState>,
    ledger_serial_num: String,
) -> Result<ApiResponse<Vec<FamilyLedgerAccountResponse>>, String> {
    let service = FamilyLedgerAccountService::default();
    Ok(ApiResponse::from_result(
        service
            .list_by_ledger(&state.db, &ledger_serial_num)
            .await
            .map(|models| models.into_iter().map(FamilyLedgerAccountResponse::from).collect()),
    ))
}

/// 根据账户ID获取账本关联
#[tauri::command]
pub async fn family_ledger_account_list_by_account(
    state: State<'_, AppState>,
    account_serial_num: String,
) -> Result<ApiResponse<Vec<FamilyLedgerAccountResponse>>, String> {
    let service = FamilyLedgerAccountService::default();
    Ok(ApiResponse::from_result(
        service
            .list_by_account(&state.db, &account_serial_num)
            .await
            .map(|models| models.into_iter().map(FamilyLedgerAccountResponse::from).collect()),
    ))
}

/// 创建账本账户关联
#[tauri::command]
pub async fn family_ledger_account_create(
    state: State<'_, AppState>,
    data: FamilyLedgerAccountCreate,
) -> Result<ApiResponse<FamilyLedgerAccountResponse>, String> {
    let service = FamilyLedgerAccountService::default();
    Ok(ApiResponse::from_result(
        service
            .create(&state.db, data.family_ledger_serial_num, data.account_serial_num)
            .await
            .map(FamilyLedgerAccountResponse::from),
    ))
}

/// 删除账本账户关联
#[tauri::command]
pub async fn family_ledger_account_delete(
    state: State<'_, AppState>,
    ledger_serial_num: String,
    account_serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = FamilyLedgerAccountService::default();
    Ok(ApiResponse::from_result(
        service
            .delete(&state.db, &ledger_serial_num, &account_serial_num)
            .await,
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
    let service = TransactionService::default();
    Ok(ApiResponse::from_result(
        service.get_transaction_stats(&state.db, request).await,
    ))
}

// ============================================================================
// Split Rules API

/// 获取分摊规则列表
#[tauri::command]
pub async fn split_rules_list(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<Vec<SplitRuleResponse>>, String> {
    let service = SplitRulesService::default();
    Ok(ApiResponse::from_result(
        service
            .find_by_family_ledger(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

/// 创建分摊规则
#[tauri::command]
pub async fn split_rules_create(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    data: SplitRuleCreate,
) -> Result<ApiResponse<SplitRuleResponse>, String> {
    let service = SplitRulesService::default();
    Ok(ApiResponse::from_result(
        service
            .create_rule(&state.db, &family_ledger_serial_num, data)
            .await,
    ))
}

/// 更新分摊规则
#[tauri::command]
pub async fn split_rules_update(
    state: State<'_, AppState>,
    rule_serial_num: String,
    data: SplitRuleUpdate,
) -> Result<ApiResponse<SplitRuleResponse>, String> {
    let service = SplitRulesService::default();
    Ok(ApiResponse::from_result(
        service
            .update_by_id(&state.db, &rule_serial_num, data)
            .await,
    ))
}

/// 删除分摊规则
#[tauri::command]
pub async fn split_rules_delete(
    state: State<'_, AppState>,
    rule_serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = SplitRulesService::default();
    Ok(ApiResponse::from_result(
        service.delete_by_id(&state.db, &rule_serial_num).await,
    ))
}

/// 设置默认分摊规则
#[tauri::command]
pub async fn split_rules_set_default(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    rule_serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = SplitRulesService::default();
    Ok(ApiResponse::from_result(
        service
            .set_default_rule(&state.db, &family_ledger_serial_num, &rule_serial_num)
            .await,
    ))
}

// ============================================================================
// Split Records API

/// 获取分摊记录列表
#[tauri::command]
pub async fn split_records_list(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<Vec<SplitRecordResponse>>, String> {
    let service = SplitRecordsService::default();
    Ok(ApiResponse::from_result(
        service
            .find_by_family_ledger(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

/// 创建分摊记录
#[tauri::command]
pub async fn split_records_create(
    state: State<'_, AppState>,
    data: SplitRecordCreate,
) -> Result<ApiResponse<SplitRecordResponse>, String> {
    let service = SplitRecordsService::default();
    Ok(ApiResponse::from_result(
        service
            .create(&state.db, data)
            .await
            .map(SplitRecordResponse::from),
    ))
}

/// 确认分摊记录
#[tauri::command]
pub async fn split_records_confirm(
    state: State<'_, AppState>,
    confirm_request: SplitRecordConfirm,
) -> Result<ApiResponse<Vec<SplitRecordResponse>>, String> {
    let service = SplitRecordsService::default();
    Ok(ApiResponse::from_result(
        service.confirm_records(&state.db, confirm_request).await,
    ))
}

/// 支付分摊记录
#[tauri::command]
pub async fn split_records_pay(
    state: State<'_, AppState>,
    payment_request: SplitRecordPayment,
) -> Result<ApiResponse<Vec<SplitRecordResponse>>, String> {
    let service = SplitRecordsService::default();
    Ok(ApiResponse::from_result(
        service.pay_records(&state.db, payment_request).await,
    ))
}

/// 获取分摊统计
#[tauri::command]
pub async fn split_records_stats(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<SplitRecordStats>, String> {
    let service = SplitRecordsService::default();
    Ok(ApiResponse::from_result(
        service
            .get_statistics(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

// ============================================================================
// Debt Relations API

/// 获取债务关系列表
#[tauri::command]
pub async fn debt_relations_list(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<Vec<DebtRelationResponse>>, String> {
    let service = DebtRelationsService::default();
    Ok(ApiResponse::from_result(
        service
            .find_by_family_ledger(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

/// 获取债务统计
#[tauri::command]
pub async fn debt_relations_stats(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<DebtStats>, String> {
    let service = DebtRelationsService::default();
    Ok(ApiResponse::from_result(
        service
            .get_debt_statistics(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

/// 获取成员债务汇总
#[tauri::command]
pub async fn debt_relations_member_summary(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    member_serial_num: String,
) -> Result<ApiResponse<MemberDebtSummary>, String> {
    let service = DebtRelationsService::default();
    Ok(ApiResponse::from_result(
        service
            .get_member_debt_summary(&state.db, &family_ledger_serial_num, &member_serial_num)
            .await,
    ))
}

/// 获取债务关系图谱
#[tauri::command]
pub async fn debt_relations_graph(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<DebtGraph>, String> {
    let service = DebtRelationsService::default();
    Ok(ApiResponse::from_result(
        service
            .get_debt_graph(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

/// 重新计算所有债务关系
#[tauri::command]
pub async fn debt_relations_recalculate(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    updated_by: String,
) -> Result<ApiResponse<i64>, String> {
    let service = DebtRelationsService::default();
    Ok(ApiResponse::from_result(
        service
            .sync_from_split_records(&state.db, &family_ledger_serial_num, &updated_by)
            .await,
    ))
}

// ============================================================================
// Settlement Records API

/// 生成结算建议
#[tauri::command]
pub async fn settlement_generate_suggestion(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    period_start: String, // YYYY-MM-DD
    period_end: String,   // YYYY-MM-DD
) -> Result<ApiResponse<SettlementSuggestion>, String> {
    let service = SettlementRecordsService::default();
    let start_date = period_start
        .parse()
        .map_err(|e| format!("Invalid start date: {}", e))?;
    let end_date = period_end
        .parse()
        .map_err(|e| format!("Invalid end date: {}", e))?;

    Ok(ApiResponse::from_result(
        service
            .generate_settlement_suggestion(
                &state.db,
                &family_ledger_serial_num,
                start_date,
                end_date,
            )
            .await,
    ))
}

/// 获取结算记录列表
#[tauri::command]
pub async fn settlement_records_list(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<Vec<SettlementRecordResponse>>, String> {
    let service = SettlementRecordsService::default();
    Ok(ApiResponse::from_result(
        service
            .find_by_family_ledger(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

/// 获取结算统计
#[tauri::command]
pub async fn settlement_records_stats(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<SettlementStats>, String> {
    let service = SettlementRecordsService::default();
    Ok(ApiResponse::from_result(
        service
            .get_settlement_statistics(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

// ============================================================================
// Family Statistics API

/// 获取家庭财务总览
#[tauri::command]
pub async fn family_statistics_overview(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    period_start: String,
    period_end: String,
) -> Result<ApiResponse<crate::services::family_statistics::FamilyFinancialOverview>, String> {
    let service = FamilyStatisticsService::default();
    let start_date = period_start
        .parse()
        .map_err(|e| format!("Invalid start date: {}", e))?;
    let end_date = period_end
        .parse()
        .map_err(|e| format!("Invalid end date: {}", e))?;

    Ok(ApiResponse::from_result(
        service
            .get_financial_overview(&state.db, &family_ledger_serial_num, start_date, end_date)
            .await,
    ))
}

/// 获取成员贡献统计
#[tauri::command]
pub async fn family_statistics_member_contributions(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    period_start: String,
    period_end: String,
) -> Result<ApiResponse<Vec<crate::services::family_statistics::MemberContribution>>, String> {
    let service = FamilyStatisticsService::default();
    let start_date = period_start
        .parse()
        .map_err(|e| format!("Invalid start date: {}", e))?;
    let end_date = period_end
        .parse()
        .map_err(|e| format!("Invalid end date: {}", e))?;

    Ok(ApiResponse::from_result(
        service
            .get_member_contributions(&state.db, &family_ledger_serial_num, start_date, end_date)
            .await,
    ))
}

/// 获取分类统计
#[tauri::command]
pub async fn family_statistics_categories(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    period_start: String,
    period_end: String,
) -> Result<ApiResponse<Vec<crate::services::family_statistics::CategoryStatistics>>, String> {
    let service = FamilyStatisticsService::default();
    let start_date = period_start
        .parse()
        .map_err(|e| format!("Invalid start date: {}", e))?;
    let end_date = period_end
        .parse()
        .map_err(|e| format!("Invalid end date: {}", e))?;

    Ok(ApiResponse::from_result(
        service
            .get_category_statistics(&state.db, &family_ledger_serial_num, start_date, end_date)
            .await,
    ))
}

/// 获取趋势分析
#[tauri::command]
pub async fn family_statistics_trends(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    period_start: String,
    period_end: String,
    granularity: String, // "monthly" or "daily"
) -> Result<ApiResponse<Vec<crate::services::family_statistics::TrendAnalysis>>, String> {
    let service = FamilyStatisticsService::default();
    let start_date = period_start
        .parse()
        .map_err(|e| format!("Invalid start date: {}", e))?;
    let end_date = period_end
        .parse()
        .map_err(|e| format!("Invalid end date: {}", e))?;

    Ok(ApiResponse::from_result(
        service
            .get_trend_analysis(
                &state.db,
                &family_ledger_serial_num,
                start_date,
                end_date,
                &granularity,
            )
            .await,
    ))
}

/// 获取债务分析
#[tauri::command]
pub async fn family_statistics_debt_analysis(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<crate::services::family_statistics::DebtAnalysis>, String> {
    let service = FamilyStatisticsService::default();
    Ok(ApiResponse::from_result(
        service
            .get_debt_analysis(&state.db, &family_ledger_serial_num)
            .await,
    ))
}

// ============================================================================
// start 家庭账本相关
// ============================================================================

/// 获取家庭账本列表
#[tauri::command]
pub async fn family_ledger_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<FamilyLedgerResponse>>, String> {
    let service = FamilyLedgerService::default();
    Ok(ApiResponse::from_result(
        service
            .family_ledger_list(&state.db)
            .await
            .map(|models| models.into_iter().map(FamilyLedgerResponse::from).collect()),
    ))
}

/// 获取家庭账本详情
#[tauri::command]
pub async fn family_ledger_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<Option<FamilyLedgerResponse>>, String> {
    let service = FamilyLedgerService::default();
    Ok(ApiResponse::from_result(
        service
            .get_by_id(&state.db, serial_num)
            .await
            .map(|model| model.map(FamilyLedgerResponse::from)),
    ))
}

/// 创建家庭账本
#[tauri::command]
pub async fn family_ledger_create(
    state: State<'_, AppState>,
    data: FamilyLedgerCreate,
) -> Result<ApiResponse<FamilyLedgerResponse>, String> {
    let service = FamilyLedgerService::default();
    Ok(ApiResponse::from_result(
        service
            .create(&state.db, data)
            .await
            .map(FamilyLedgerResponse::from),
    ))
}

/// 获取家庭账本交易关联列表
#[tauri::command]
pub async fn family_ledger_transaction_list(
    state: State<'_, AppState>,
    filter: Option<FamilyLedgerTransactionFilter>,
) -> Result<ApiResponse<Vec<FamilyLedgerTransactionResponse>>, String> {
    let service = FamilyLedgerTransactionService::default();
    Ok(ApiResponse::from_result(
        service
            .list_associations(&state.db, filter)
            .await
            .map(|rows| rows.into_iter().map(FamilyLedgerTransactionResponse::from).collect()),
    ))
}

/// 创建家庭账本交易关联
#[tauri::command]
pub async fn family_ledger_transaction_create(
    state: State<'_, AppState>,
    data: FamilyLedgerTransactionCreate,
) -> Result<ApiResponse<FamilyLedgerTransactionResponse>, String> {
    let service = FamilyLedgerTransactionService::default();
    Ok(ApiResponse::from_result(
        service
            .create_association(&state.db, data)
            .await
            .map(FamilyLedgerTransactionResponse::from),
    ))
}

/// 获取家庭账本交易关联详情
#[tauri::command]
pub async fn family_ledger_transaction_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<Option<FamilyLedgerTransactionResponse>>, String> {
    let service = FamilyLedgerTransactionService::default();
    Ok(ApiResponse::from_result(
        service
            .get_association_by_serial(&state.db, &serial_num)
            .await
            .map(|opt| opt.map(FamilyLedgerTransactionResponse::from)),
    ))
}

/// 更新家庭账本交易关联
#[tauri::command]
pub async fn family_ledger_transaction_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: FamilyLedgerTransactionUpdate,
) -> Result<ApiResponse<FamilyLedgerTransactionResponse>, String> {
    let service = FamilyLedgerTransactionService::default();
    Ok(ApiResponse::from_result(
        service
            .update_association(&state.db, serial_num, data)
            .await
            .map(FamilyLedgerTransactionResponse::from),
    ))
}

/// 删除家庭账本交易关联
#[tauri::command]
pub async fn family_ledger_transaction_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = FamilyLedgerTransactionService::default();
    Ok(ApiResponse::from_result(
        service.delete_association(&state.db, serial_num).await,
    ))
}

/// 分页获取家庭账本交易关联
#[tauri::command]
pub async fn family_ledger_transaction_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<FamilyLedgerTransactionFilter>,
) -> Result<ApiResponse<PagedResult<FamilyLedgerTransactionResponse>>, String> {
    let service = FamilyLedgerTransactionService::default();
    Ok(ApiResponse::from_result(
        service
            .list_associations_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged
                    .rows
                    .into_iter()
                    .map(FamilyLedgerTransactionResponse::from)
                    .collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}

/// 更新家庭账本
#[tauri::command]
pub async fn family_ledger_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: FamilyLedgerUpdate,
) -> Result<ApiResponse<FamilyLedgerResponse>, String> {
    let service = FamilyLedgerService::default();
    Ok(ApiResponse::from_result(
        service
            .update(&state.db, serial_num, data)
            .await
            .map(FamilyLedgerResponse::from),
    ))
}

/// 删除家庭账本
#[tauri::command]
pub async fn family_ledger_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = FamilyLedgerService::default();
    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

/// 获取家庭账本统计信息
#[tauri::command]
pub async fn family_ledger_stats(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<FamilyLedgerStats>, String> {
    let service = FamilyLedgerService::default();
    Ok(ApiResponse::from_result(
        service.get_stats(&state.db, serial_num).await,
    ))
}

/// 获取家庭账本详情（包含成员和账户列表）
#[tauri::command]
pub async fn family_ledger_detail(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<FamilyLedgerDetailResponse>, String> {
    let service = FamilyLedgerService::default();
    Ok(ApiResponse::from_result(
        service.get_detail(&state.db, serial_num).await,
    ))
}

// ============================================================================
// end 家庭账本相关
// ============================================================================
