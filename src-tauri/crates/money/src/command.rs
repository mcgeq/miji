use std::collections::HashMap;

use common::{
    ApiResponse, AppState,
    crud::service::CrudService,
    error::AppError,
    paginations::{PagedQuery, PagedResult},
};
use sea_orm::{prelude::Decimal, ActiveModelTrait, ActiveValue};
use serde_json::Value as JsonValue;
use tauri::State;
use tracing::{error, info, instrument, warn};
use validator::Validate;

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
        family_budget::{
            BudgetAllocationCreateRequest, BudgetAllocationResponse, BudgetAllocationUpdateRequest,
            BudgetAlertResponse, BudgetUsageRequest,
        },
        family_ledger::{
            FamilyLedgerCreate, FamilyLedgerDetailResponse, FamilyLedgerResponse, FamilyLedgerStats, FamilyLedgerUpdate,
        },
        family_ledger_account::{FamilyLedgerAccountCreate, FamilyLedgerAccountResponse},
        family_ledger_member::{FamilyLedgerMemberCreate, FamilyLedgerMemberResponse},
        family_ledger_transaction::{
            FamilyLedgerTransactionCreate, FamilyLedgerTransactionFilter,
            FamilyLedgerTransactionResponse, FamilyLedgerTransactionUpdate,
        },
        family_member::{
            FamilyMemberCreate, FamilyMemberResponse, FamilyMemberUpdate, FamilyMemberSearchQuery, FamilyMemberSearchResponse
        },
        installment::{
            InstallmentCalculationRequest, InstallmentCalculationResponse, InstallmentPlanResponse,
        },
        settlement_records::{SettlementRecordResponse, SettlementStats, SettlementSuggestion},
        split_records::{
            SplitRecordConfirm, SplitRecordCreate, SplitRecordPayment, SplitRecordResponse,
            SplitRecordStats,
        },
        split_record_details::{
            SplitRecordDetailResponse, SplitRecordWithDetails, SplitRecordWithDetailsCreate,
            SplitRecordStatistics,
        },
        split_rules::{SplitRuleCreate, SplitRuleResponse, SplitRuleUpdate},
        sub_categories::{SubCategory, SubCategoryCreate, SubCategoryUpdate},
        transactions::{
            CreateTransactionRequest, IncomeExpense, TransactionResponse, TransactionStatsRequest,
            TransactionStatsResponse, TransferRequest, UpdateTransactionRequest,
        },
        user_settings::{
            SaveSettingCommand, UserSettingResponse,
        },
    },
    services::{
        account::{AccountFilter, AccountService},
        bil_reminder::{BilReminderFilters, BilReminderService},
        budget::{BudgetFilter, BudgetService},
        budget_allocation::BudgetAllocationService,
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
        split_record_details::SplitRecordDetailService,
        split_rules::SplitRulesService,
        sub_categories::{SubCategoryFilter, SubCategoryService},
        transaction::{TransactionFilter, TransactionService},
        user_settings::UserSettingExtService,
    },
};

// ============================================================================
// start 分期付款相关
// 获取分期付款计划（根据分期计划序列号）
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

// 获取分期付款计划（根据交易序列号）
#[tauri::command]
pub async fn installment_plan_get_by_transaction(
    state: State<'_, AppState>,
    transaction_serial_num: String,
) -> Result<ApiResponse<InstallmentPlanResponse>, String> {
    let service = InstallmentService::default();
    Ok(ApiResponse::from_result(
        service
            .get_installment_plan_by_transaction(&state.db, &transaction_serial_num)
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
        family_ledger_serial_nums = ?data.family_ledger_serial_nums,
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
        .trans_get_response(&state.db, serial_num.clone())
        .await
    {
        Ok(result) => {
            info!(
                transaction_serial_num = %result.serial_num,
                amount = %result.amount,
                transaction_type = ?result.transaction_type,
                has_split_config = result.split_config.is_some(),
                "获取交易成功"
            );
            Ok(ApiResponse::from_result(Ok(result)))
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

/// 搜索家庭成员
#[tauri::command]
#[instrument(skip(state))]
pub async fn search_family_members(
    state: State<'_, AppState>,
    query: FamilyMemberSearchQuery,
    limit: Option<u32>,
) -> Result<ApiResponse<FamilyMemberSearchResponse>, String> {
    info!(
        keyword = ?query.keyword,
        name = ?query.name,
        email = ?query.email,
        limit = ?limit,
        "开始搜索家庭成员"
    );

    let service = FamilyMemberService::default();
    let search_limit = limit.unwrap_or(20).min(100); // 最大限制100个结果

    match service.search_family_members(&state.db, query, Some(search_limit)).await {
        Ok(members) => {
            let member_count = members.len();
            let response = FamilyMemberSearchResponse {
                members: members.into_iter().map(FamilyMemberResponse::from).collect(),
                total: member_count as u64,
                has_more: member_count >= search_limit as usize,
            };
            
            info!(
                result_count = member_count,
                has_more = response.has_more,
                "家庭成员搜索成功"
            );
            Ok(ApiResponse::from_result(Ok(response)))
        }
        Err(e) => {
            error!(
                error = %e,
                "家庭成员搜索失败"
            );
            Err(e.to_string())
        }
    }
}

/// 获取最近创建的家庭成员
#[tauri::command]
#[instrument(skip(state))]
pub async fn list_recent_family_members(
    state: State<'_, AppState>,
    limit: Option<u32>,
    days_back: Option<u32>,
) -> Result<ApiResponse<Vec<FamilyMemberResponse>>, String> {
    info!(
        limit = ?limit,
        days_back = ?days_back,
        "开始获取最近家庭成员"
    );

    let service = FamilyMemberService::default();

    match service.list_recent_family_members(&state.db, limit, days_back).await {
        Ok(members) => {
            info!(
                count = members.len(),
                "获取最近家庭成员成功"
            );
            Ok(ApiResponse::from_result(Ok(members
                .into_iter()
                .map(FamilyMemberResponse::from)
                .collect())))
        }
        Err(e) => {
            error!(
                error = %e,
                "获取最近家庭成员失败"
            );
            Err(e.to_string())
        }
    }
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

/// 获取单个债务关系
#[tauri::command]
pub async fn debt_relation_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<DebtRelationResponse>, String> {
    let service = DebtRelationsService::default();
    Ok(ApiResponse::from_result(
        service.inner.get_by_id(&state.db, serial_num).await.map(Into::into),
    ))
}

/// 标记债务关系为已结算
#[tauri::command]
pub async fn debt_relation_mark_settled(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = DebtRelationsService::default();
    let update = crate::dto::debt_relations::DebtRelationUpdate {
        status: Some("Settled".to_string()),
        amount: None,
        notes: None,
    };
    service.inner.update(&state.db, serial_num, update).await
        .map_err(|e| e.to_string())?;
    Ok(ApiResponse::success(()))
}

/// 标记债务关系为已取消
#[tauri::command]
pub async fn debt_relation_mark_cancelled(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = DebtRelationsService::default();
    let update = crate::dto::debt_relations::DebtRelationUpdate {
        status: Some("Cancelled".to_string()),
        amount: None,
        notes: None,
    };
    service.inner.update(&state.db, serial_num, update).await
        .map_err(|e| e.to_string())?;
    Ok(ApiResponse::success(()))
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

/// 执行结算
#[tauri::command]
pub async fn settlement_execute(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    settlement_type: String,
    period_start: String,
    period_end: String,
    participant_members: serde_json::Value,
    optimized_transfers: Option<serde_json::Value>,
    total_amount: Decimal,
    currency: String,
    initiated_by: String,
) -> Result<ApiResponse<SettlementRecordResponse>, String> {
    let service = SettlementRecordsService::default();
    let start_date = period_start
        .parse()
        .map_err(|e| format!("Invalid start date: {}", e))?;
    let end_date = period_end
        .parse()
        .map_err(|e| format!("Invalid end date: {}", e))?;
    
    let create_data = crate::dto::settlement_records::SettlementRecordCreate {
        settlement_type,
        period_start: start_date,
        period_end: end_date,
        total_amount,
        currency,
        participant_members,
        settlement_details: serde_json::json!({}), // 将由服务层填充
        optimized_transfers,
        description: None,
        notes: None,
    };
    
    Ok(ApiResponse::from_result(
        async {
            let model = service.inner.create(&state.db, create_data).await?;
            // 更新额外字段
            let mut active_model: entity::settlement_records::ActiveModel = model.into();
            active_model.family_ledger_serial_num = ActiveValue::Set(family_ledger_serial_num);
            active_model.initiated_by = ActiveValue::Set(initiated_by);
            let updated_model = active_model.update(state.db.as_ref()).await?;
            Ok::<SettlementRecordResponse, AppError>(updated_model.into())
        }.await,
    ))
}

/// 获取优化详情
#[tauri::command]
pub async fn settlement_get_optimization_details(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
) -> Result<ApiResponse<serde_json::Value>, String> {
    // 这里返回优化前后的对比信息
    let service = DebtRelationsService::default();
    let debts = service
        .find_by_family_ledger(&state.db, &family_ledger_serial_num)
        .await
        .map_err(|e| e.to_string())?;
    
    let original_count = debts.len();
    // 简化计算：假设优化后减少30%的转账次数
    let optimized_count = (original_count as f64 * 0.7) as i32;
    let savings = original_count as i32 - optimized_count;
    
    let details = serde_json::json!({
        "before": {
            "transferCount": original_count,
            "complexity": "high"
        },
        "after": {
            "transferCount": optimized_count,
            "complexity": "optimized"
        },
        "savings": savings,
        "savingsPercentage": ((savings as f64 / original_count as f64) * 100.0).round()
    });
    
    Ok(ApiResponse::success(details))
}

/// 验证结算方案
#[tauri::command]
pub async fn settlement_validate(
    _state: State<'_, AppState>,
    transfers: Vec<serde_json::Value>,
) -> Result<ApiResponse<serde_json::Value>, String> {
    // 验证转账方案是否平衡
    let mut errors = Vec::new();
    
    if transfers.is_empty() {
        errors.push("转账列表不能为空");
    }
    
    // TODO: 添加更多验证逻辑
    // 1. 检查转账是否平衡
    // 2. 检查是否有循环转账
    // 3. 检查金额是否合理
    
    let is_valid = errors.is_empty();
    let result = serde_json::json!({
        "isValid": is_valid,
        "errors": errors
    });
    
    Ok(ApiResponse::success(result))
}

/// 获取单个结算记录
#[tauri::command]
pub async fn settlement_record_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<SettlementRecordResponse>, String> {
    let service = SettlementRecordsService::default();
    Ok(ApiResponse::from_result(
        service.inner.get_by_id(&state.db, serial_num).await.map(Into::into),
    ))
}

/// 完成结算
#[tauri::command]
pub async fn settlement_record_complete(
    state: State<'_, AppState>,
    serial_num: String,
    completed_by: String,
) -> Result<ApiResponse<()>, String> {
    let service = SettlementRecordsService::default();
    let update = crate::dto::settlement_records::SettlementRecordUpdate {
        status: Some("Completed".to_string()),
        optimized_transfers: None,
        description: None,
        notes: None,
    };
    
    let model = service.inner.update(&state.db, serial_num.clone(), update).await
        .map_err(|e| e.to_string())?;
    
    // 更新完成人
    let mut active_model: entity::settlement_records::ActiveModel = model.into();
    active_model.completed_by = ActiveValue::Set(Some(completed_by));
    active_model.update(state.db.as_ref()).await.map_err(|e| e.to_string())?;
    
    Ok(ApiResponse::success(()))
}

/// 取消结算
#[tauri::command]
pub async fn settlement_record_cancel(
    state: State<'_, AppState>,
    serial_num: String,
    cancellation_reason: Option<String>,
) -> Result<ApiResponse<()>, String> {
    let service = SettlementRecordsService::default();
    let update = crate::dto::settlement_records::SettlementRecordUpdate {
        status: Some("Cancelled".to_string()),
        optimized_transfers: None,
        description: None,
        notes: cancellation_reason,
    };
    
    service.inner.update(&state.db, serial_num, update).await
        .map_err(|e| e.to_string())?;
    
    Ok(ApiResponse::success(()))
}

/// 导出单个结算记录
#[tauri::command]
pub async fn settlement_record_export(
    state: State<'_, AppState>,
    serial_num: String,
    format: String,
) -> Result<ApiResponse<serde_json::Value>, String> {
    let service = SettlementRecordsService::default();
    let record = service.inner.get_by_id(&state.db, serial_num).await
        .map_err(|e| e.to_string())?;
    
    // TODO: 实现实际的导出逻辑（PDF/Excel）
    let filename = format!("settlement_{}_{}.{}", record.serial_num, 
        chrono::Local::now().format("%Y%m%d"), format);
    
    let result = serde_json::json!({
        "filename": filename,
        "data": "base64_encoded_data_here", // TODO: 实际导出数据
        "format": format
    });
    
    Ok(ApiResponse::success(result))
}

/// 批量导出结算记录
#[tauri::command]
pub async fn settlement_records_export(
    state: State<'_, AppState>,
    family_ledger_serial_num: String,
    format: String,
    status: Option<String>,
) -> Result<ApiResponse<serde_json::Value>, String> {
    let service = SettlementRecordsService::default();
    let mut records = service
        .find_by_family_ledger(&state.db, &family_ledger_serial_num)
        .await
        .map_err(|e| e.to_string())?;
    
    // 根据状态筛选
    if let Some(status_filter) = status {
        records.retain(|r| r.status == status_filter);
    }
    
    // TODO: 实现实际的批量导出逻辑
    let filename = format!("settlements_{}_{}.{}", 
        family_ledger_serial_num,
        chrono::Local::now().format("%Y%m%d"), 
        format);
    
    let result = serde_json::json!({
        "filename": filename,
        "data": "base64_encoded_data_here", // TODO: 实际导出数据
        "format": format,
        "recordCount": records.len()
    });
    
    Ok(ApiResponse::success(result))
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
        async {
            let models = service.family_ledger_list(&state.db).await?;
            service.models_to_responses(&state.db, models).await
        }
        .await,
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
        async {
            if let Some(model) = service.get_by_id(&state.db, serial_num).await? {
                Ok(Some(service.model_to_response(&state.db, model).await?))
            } else {
                Ok(None)
            }
        }
        .await,
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
        async {
            let model = service.create(&state.db, data).await?;
            service.model_to_response(&state.db, model).await
        }
        .await,
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
        async {
            let model = service.update(&state.db, serial_num, data).await?;
            service.model_to_response(&state.db, model).await
        }
        .await,
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

// ============================================================================
// 数据迁移相关 - 已废弃
// ============================================================================
// 注意：此功能已废弃，split_members 字段已从数据库中完全移除
// 所有新数据直接使用 split_records 和 split_record_details 表
// 相关前端 UI 保留但功能已禁用

/* 已废弃 - 注释掉以避免编译错误
/// 迁移历史交易的 split_members 到 split_records 表
#[tauri::command]
#[instrument]
pub async fn migrate_split_records(
    _state: State<'_, AppState>,
) -> Result<ApiResponse<MigrationResult>, String> {
    use std::time::Instant;
    
    info!("开始迁移 split_records 数据");
    let start = Instant::now();
    
    let mut result = MigrationResult::new();
    
    // split_members 字段已删除，无需迁移
    // 所有历史数据都是空的，直接返回成功
    info!("split_members 字段已从数据库中删除，无需迁移");
    
    result.duration_ms = start.elapsed().as_millis();
    
    Ok(ApiResponse::success(result))
}

/// 获取 split_records 统计信息（用于监控）
#[tauri::command]
#[instrument(skip(state))]
pub async fn get_split_records_stats(
    state: State<'_, AppState>,
) -> Result<ApiResponse<serde_json::Value>, String> {
    use sea_orm::{EntityTrait, QuerySelect, PaginatorTrait};
    
    let db = state.db.as_ref();
    
    // 1. 总记录数
    let total_count = entity::split_records::Entity::find()
        .count(db)
        .await
        .map_err(|e| format!("查询失败: {}", e))?;
    
    // 2. 有 split_members 的交易数（字段已删除，返回 0）
    let transactions_with_split_members: u64 = 0;
    
    // 3. 已迁移的交易数（有 split_records 的唯一交易）
    let migrated_transactions = entity::split_records::Entity::find()
        .select_only()
        .column(entity::split_records::Column::TransactionSerialNum)
        .distinct()
        .all(db)
        .await
        .map_err(|e| format!("查询失败: {}", e))?
        .len();
    
    // 4. 待迁移的交易数
    let pending_migrations = transactions_with_split_members.saturating_sub(migrated_transactions as u64);
    
    let stats = serde_json::json!({
        "totalSplitRecords": total_count,
        "transactionsWithSplitMembers": transactions_with_split_members,
        "migratedTransactions": migrated_transactions,
        "pendingMigrations": pending_migrations,
        "progressPercentage": if transactions_with_split_members > 0 {
            migrated_transactions as f64 / transactions_with_split_members as f64 * 100.0
        } else {
            100.0 // 没有需要迁移的数据，进度100%
        },
    });
    
    info!("Split records stats: {:?}", stats);
    Ok(ApiResponse::success(stats))
}
*/

// ============================================================================
// end 数据迁移相关
// ============================================================================

// ============================================================================
// start 分摊记录明细相关 (基于新的 split_record_details 表)
// ============================================================================

/// 创建完整的分摊记录（主记录 + 所有明细）
#[tauri::command]
#[instrument(skip(state))]
pub async fn split_record_with_details_create(
    state: State<'_, AppState>,
    data: SplitRecordWithDetailsCreate,
) -> Result<ApiResponse<SplitRecordWithDetails>, String> {
    let service = SplitRecordDetailService::default();
    info!("Creating split record with {} details", data.details.len());
    
    Ok(ApiResponse::from_result(
        service
            .create_split_record_with_details(&state.db, data)
            .await,
    ))
}

/// 获取分摊记录详情（包含所有明细）
#[tauri::command]
#[instrument(skip(state))]
pub async fn split_record_with_details_get(
    state: State<'_, AppState>,
    split_record_serial_num: String,
) -> Result<ApiResponse<SplitRecordWithDetails>, String> {
    let service = SplitRecordDetailService::default();
    
    Ok(ApiResponse::from_result(
        service
            .get_split_record_with_details(&state.db, split_record_serial_num)
            .await,
    ))
}

/// 更新分摊明细的支付状态
#[tauri::command]
#[instrument(skip(state))]
pub async fn split_detail_payment_status_update(
    state: State<'_, AppState>,
    detail_serial_num: String,
    is_paid: bool,
) -> Result<ApiResponse<SplitRecordDetailResponse>, String> {
    let service = SplitRecordDetailService::default();
    info!("Updating payment status for detail: {}, is_paid: {}", detail_serial_num, is_paid);
    
    Ok(ApiResponse::from_result(
        service
            .update_detail_payment_status(&state.db, detail_serial_num, is_paid)
            .await,
    ))
}

/// 获取分摊记录的统计信息
#[tauri::command]
#[instrument(skip(state))]
pub async fn split_record_statistics_get(
    state: State<'_, AppState>,
    split_record_serial_num: String,
) -> Result<ApiResponse<SplitRecordStatistics>, String> {
    let service = SplitRecordDetailService::default();
    
    Ok(ApiResponse::from_result(
        service
            .get_statistics(&state.db, split_record_serial_num)
            .await,
    ))
}

/// 查询成员的所有分摊明细（分页）
#[tauri::command]
#[instrument(skip(state))]
pub async fn member_split_details_list(
    state: State<'_, AppState>,
    member_serial_num: String,
    page: Option<u64>,
    page_size: Option<u64>,
) -> Result<ApiResponse<PagedResult<SplitRecordDetailResponse>>, String> {
    let service = SplitRecordDetailService::default();
    
    Ok(ApiResponse::from_result(
        service
            .list_member_split_details(&state.db, member_serial_num, page, page_size)
            .await,
    ))
}

// ============================================================================
// end 分摊记录明细相关
// ============================================================================

// ============================================================================
// start 预算分配相关 (Phase 6)
// ============================================================================

/// 创建预算分配
#[tauri::command]
#[instrument(skip(state))]
pub async fn budget_allocation_create(
    state: State<'_, AppState>,
    budget_serial_num: String,
    data: BudgetAllocationCreateRequest,
) -> Result<ApiResponse<entity::budget_allocations::Model>, String> {
    info!("Creating budget allocation for budget: {}", budget_serial_num);
    
    Ok(ApiResponse::from_result(
        BudgetAllocationService::create(&state.db, &budget_serial_num, data).await,
    ))
}

/// 更新预算分配
#[tauri::command]
#[instrument(skip(state))]
pub async fn budget_allocation_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: BudgetAllocationUpdateRequest,
) -> Result<ApiResponse<entity::budget_allocations::Model>, String> {
    info!("Updating budget allocation: {}", serial_num);
    
    Ok(ApiResponse::from_result(
        BudgetAllocationService::update(&state.db, &serial_num, data).await,
    ))
}

/// 删除预算分配
#[tauri::command]
#[instrument(skip(state))]
pub async fn budget_allocation_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!("Deleting budget allocation: {}", serial_num);
    
    Ok(ApiResponse::from_result(
        BudgetAllocationService::delete(&state.db, &serial_num).await,
    ))
}

/// 获取预算分配详情
#[tauri::command]
#[instrument(skip(state))]
pub async fn budget_allocation_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<entity::budget_allocations::Model>, String> {
    Ok(ApiResponse::from_result(
        BudgetAllocationService::get(&state.db, &serial_num).await,
    ))
}

/// 查询预算的所有分配
#[tauri::command]
#[instrument(skip(state))]
pub async fn budget_allocations_list(
    state: State<'_, AppState>,
    budget_serial_num: String,
) -> Result<ApiResponse<Vec<entity::budget_allocations::Model>>, String> {
    Ok(ApiResponse::from_result(
        BudgetAllocationService::list_by_budget(&state.db, &budget_serial_num).await,
    ))
}

/// 记录预算使用
#[tauri::command]
#[instrument(skip(state))]
pub async fn budget_allocation_record_usage(
    state: State<'_, AppState>,
    data: BudgetUsageRequest,
) -> Result<ApiResponse<BudgetAllocationResponse>, String> {
    info!(
        "Recording budget usage: allocation={}, amount={}",
        data.allocation_serial_num.as_ref().unwrap_or(&"N/A".to_string()),
        data.amount
    );
    
    let allocation_sn = data
        .allocation_serial_num
        .ok_or_else(|| "allocation_serial_num is required".to_string())?;
    
    Ok(ApiResponse::from_result(
        BudgetAllocationService::record_usage(
            &state.db,
            &allocation_sn,
            data.amount,
            &data.transaction_serial_num,
        )
        .await,
    ))
}

/// 检查是否可以消费指定金额
#[tauri::command]
#[instrument(skip(state))]
pub async fn budget_allocation_can_spend(
    state: State<'_, AppState>,
    allocation_serial_num: String,
    amount: String, // 使用String避免精度问题
) -> Result<ApiResponse<(bool, Option<String>)>, String> {
    use std::str::FromStr;
    
    let amount = Decimal::from_str(&amount)
        .map_err(|e| format!("Invalid amount: {}", e))?;
    
    Ok(ApiResponse::from_result(
        BudgetAllocationService::can_spend(&state.db, &allocation_serial_num, amount).await,
    ))
}

/// 检查预算预警
#[tauri::command]
#[instrument(skip(state))]
pub async fn budget_allocation_check_alerts(
    state: State<'_, AppState>,
    budget_serial_num: String,
) -> Result<ApiResponse<Vec<BudgetAlertResponse>>, String> {
    Ok(ApiResponse::from_result(
        BudgetAllocationService::check_alerts(&state.db, &budget_serial_num).await,
    ))
}

// ============================================================================
// end 预算分配相关
// ============================================================================

// ============================================================================
// start 用户设置相关
// ============================================================================

/// 获取单个用户设置
#[tauri::command]
#[instrument(skip(state))]
pub async fn user_setting_get(
    state: State<'_, AppState>,
    key: String,
) -> Result<ApiResponse<Option<JsonValue>>, String> {
    // TODO: 从认证系统获取当前用户ID
    let user_serial_num = "user-default".to_string(); // 临时硬编码，实际应从session获取
    
    Ok(ApiResponse::from_result(
        UserSettingExtService::get_setting(&state.db, &user_serial_num, &key).await,
    ))
}

/// 保存单个用户设置
#[tauri::command]
#[instrument(skip(state, command), fields(key = %command.key, setting_type = %command.setting_type, module = %command.module))]
pub async fn user_setting_save(
    state: State<'_, AppState>,
    command: SaveSettingCommand,
) -> Result<ApiResponse<UserSettingResponse>, String> {
    info!("Saving user setting");
    
    // 验证命令
    command.validate()
        .map_err(|e| {
            warn!("Validation failed: {}", e);
            format!("Validation error: {}", e)
        })?;
    
    // TODO: 从认证系统获取当前用户ID
    let user_serial_num = "user-default".to_string();
    info!("User ID: {}", user_serial_num);
    
    // 转换为内部请求
    let request = command.to_create_request(user_serial_num);
    
    // 调用服务层保存
    let result = UserSettingExtService::save_setting(
        &state.db,
        &request.user_serial_num,
        &request.setting_key,
        request.setting_value,
        request.setting_type,
        request.module,
    )
    .await;
    
    match &result {
        Ok(_) => info!("Setting saved successfully"),
        Err(e) => error!("Failed to save setting: {:?}", e),
    }
    
    Ok(ApiResponse::from_result(result))
}

/// 获取模块所有设置
#[tauri::command]
#[instrument(skip(state))]
pub async fn user_setting_get_module(
    state: State<'_, AppState>,
    module: String,
) -> Result<ApiResponse<HashMap<String, JsonValue>>, String> {
    // TODO: 从认证系统获取当前用户ID
    let user_serial_num = "user-default".to_string();
    
    Ok(ApiResponse::from_result(
        UserSettingExtService::get_module_settings(&state.db, &user_serial_num, &module).await,
    ))
}

/// 批量保存设置
#[tauri::command]
#[instrument(skip(state))]
pub async fn user_setting_save_batch(
    state: State<'_, AppState>,
    settings: HashMap<String, (JsonValue, String, String)>, // (value, type, module)
) -> Result<ApiResponse<Vec<UserSettingResponse>>, String> {
    // TODO: 从认证系统获取当前用户ID
    let user_serial_num = "user-default".to_string();
    
    Ok(ApiResponse::from_result(
        UserSettingExtService::save_settings_batch(&state.db, &user_serial_num, settings).await,
    ))
}

/// 删除单个设置
#[tauri::command]
#[instrument(skip(state))]
pub async fn user_setting_delete(
    state: State<'_, AppState>,
    key: String,
) -> Result<ApiResponse<bool>, String> {
    // TODO: 从认证系统获取当前用户ID
    let user_serial_num = "user-default".to_string();
    
    Ok(ApiResponse::from_result(
        UserSettingExtService::delete_setting(&state.db, &user_serial_num, &key).await,
    ))
}

/// 重置模块所有设置
#[tauri::command]
#[instrument(skip(state))]
pub async fn user_setting_reset_module(
    state: State<'_, AppState>,
    module: String,
) -> Result<ApiResponse<u64>, String> {
    // TODO: 从认证系统获取当前用户ID
    let user_serial_num = "user-default".to_string();
    
    Ok(ApiResponse::from_result(
        UserSettingExtService::reset_module_settings(&state.db, &user_serial_num, &module).await,
    ))
}

/// 获取用户所有设置
#[tauri::command]
#[instrument(skip(state))]
pub async fn user_setting_get_all(
    state: State<'_, AppState>,
) -> Result<ApiResponse<HashMap<String, JsonValue>>, String> {
    // TODO: 从认证系统获取当前用户ID
    let user_serial_num = "user-default".to_string();
    
    Ok(ApiResponse::from_result(
        UserSettingExtService::get_all_user_settings(&state.db, &user_serial_num).await,
    ))
}

// ============================================================================
// end 用户设置相关
// ============================================================================
