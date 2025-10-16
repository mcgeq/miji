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
            AccountBalanceSummary, AccountCreate, AccountResponseWithRelations, AccountUpdate,
        },
        bil_reminder::{BilReminder, BilReminderCreate, BilReminderUpdate},
        budget::{Budget, BudgetCreate, BudgetUpdate},
        categories::{Category, CategoryCreate, CategoryUpdate},
        currency::{CreateCurrencyRequest, CurrencyResponse, UpdateCurrencyRequest},
        family_member::FamilyMemberResponse,
        installment::{InstallmentDetailResponse, InstallmentPlanResponse, InstallmentPlanCreate, InstallmentPlanUpdate, PayInstallmentCreate},
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
    plan_id: String,
) -> Result<ApiResponse<InstallmentPlanResponse>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service.get_installment_plan(&state.db, &plan_id).await,
    ))
}

// 创建分期付款计划
#[tauri::command]
pub async fn installment_plan_create(
    state: State<'_, AppState>,
    data: InstallmentPlanCreate,
) -> Result<ApiResponse<InstallmentPlanResponse>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service.create_installment_plan_with_details(&state.db, data).await,
    ))
}

// 更新分期付款计划
#[tauri::command]
pub async fn installment_plan_update(
    state: State<'_, AppState>,
    plan_id: String,
    data: InstallmentPlanUpdate,
) -> Result<ApiResponse<entity::installment_plans::Model>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service.installment_plan_update(&state.db, plan_id, data).await,
    ))
}

// 删除分期付款计划
#[tauri::command]
pub async fn installment_plan_delete(
    state: State<'_, AppState>,
    plan_id: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service.installment_plan_delete(&state.db, plan_id).await,
    ))
}

// 获取分期付款计划列表
#[tauri::command]
pub async fn installment_plan_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<entity::installment_plans::Model>>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service.installment_plan_list(&state.db).await,
    ))
}

// 处理分期还款
#[tauri::command]
pub async fn installment_pay(
    state: State<'_, AppState>,
    data: PayInstallmentCreate,
) -> Result<ApiResponse<InstallmentDetailResponse>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service.pay_installment(&state.db, data).await,
    ))
}

// 获取待还款的分期明细
#[tauri::command]
pub async fn installment_pending_list(
    state: State<'_, AppState>,
    plan_serial_num: String,
) -> Result<ApiResponse<Vec<InstallmentDetailResponse>>, String> {
    let service = get_installment_service();
    Ok(ApiResponse::from_result(
        service.get_pending_installments(&state.db, &plan_serial_num).await,
    ))
}
// end 分期付款相关
// ============================================================================

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
            .map(AccountResponseWithRelations::from),
    ))
}

// 创建账户
#[tauri::command]
pub async fn account_create(
    state: State<'_, AppState>,
    data: AccountCreate,
) -> Result<ApiResponse<AccountResponseWithRelations>, String> {
    let service = get_account_service();

    Ok(ApiResponse::from_result(
        service
            .account_create(&state.db, data)
            .await
            .map(AccountResponseWithRelations::from),
    ))
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
    info!("budget_list_paged query {:?}", query);
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
