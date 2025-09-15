use common::{
    ApiResponse, AppState,
    paginations::{PagedQuery, PagedResult},
};
use tauri::State;

use crate::{
    dto::{
        period_daily_records::{
            PeriodDailyRecord, PeriodDailyRecordCreate, PeriodDailyRecordUpdate,
        },
        period_records::{PeriodRecords, PeriodRecordsCreate, PeriodRecordsUpdate},
        period_settings::{PeriodSettings, PeriodSettingsCreate, PeriodSettingsUpdate},
    },
    service::{
        period_daily_records::{PeriodDailyRecordFilter, get_period_daily_record_service},
        period_records::{PeriodRecordFilter, get_period_record_service},
        period_settings::get_settings_service,
    },
};

// ========================== Start ==========================
// Period Records
#[tauri::command]
pub async fn period_record_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<PeriodRecords>, String> {
    let service = get_period_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_record_get(&state.db, serial_num)
            .await
            .map(PeriodRecords::from),
    ))
}

#[tauri::command]
pub async fn period_record_create(
    state: State<'_, AppState>,
    data: PeriodRecordsCreate,
) -> Result<ApiResponse<PeriodRecords>, String> {
    let service = get_period_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_record_create(&state.db, data)
            .await
            .map(PeriodRecords::from),
    ))
}

#[tauri::command]
pub async fn period_record_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: PeriodRecordsUpdate,
) -> Result<ApiResponse<PeriodRecords>, String> {
    let service = get_period_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_record_update(&state.db, serial_num, data)
            .await
            .map(PeriodRecords::from),
    ))
}

#[tauri::command]
pub async fn period_record_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_period_record_service();
    Ok(ApiResponse::from_result(
        service.period_record_delete(&state.db, serial_num).await,
    ))
}

#[tauri::command]
pub async fn period_record_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<PeriodRecordFilter>,
) -> Result<ApiResponse<PagedResult<PeriodRecords>>, String> {
    let service = get_period_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_record_list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(PeriodRecords::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}
// ========================== End ==========================

// ========================== Start ==========================
#[tauri::command]
pub async fn period_daily_record_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<PeriodDailyRecord>, String> {
    let service = get_period_daily_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_daily_record_get(&state.db, serial_num)
            .await
            .map(PeriodDailyRecord::from),
    ))
}

#[tauri::command]
pub async fn period_daily_record_create(
    state: State<'_, AppState>,
    data: PeriodDailyRecordCreate,
) -> Result<ApiResponse<PeriodDailyRecord>, String> {
    let service = get_period_daily_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_daily_record_create(&state.db, data)
            .await
            .map(PeriodDailyRecord::from),
    ))
}

#[tauri::command]
pub async fn period_daily_record_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: PeriodDailyRecordUpdate,
) -> Result<ApiResponse<PeriodDailyRecord>, String> {
    let service = get_period_daily_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_daily_record_update(&state.db, serial_num, data)
            .await
            .map(PeriodDailyRecord::from),
    ))
}

#[tauri::command]
pub async fn period_daily_record_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = get_period_daily_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_daily_record_delete(&state.db, serial_num)
            .await,
    ))
}

#[tauri::command]
pub async fn period_daily_record_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<PeriodDailyRecordFilter>,
) -> Result<ApiResponse<PagedResult<PeriodDailyRecord>>, String> {
    let service = get_period_daily_record_service();
    Ok(ApiResponse::from_result(
        service
            .period_daily_record_list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged
                    .rows
                    .into_iter()
                    .map(PeriodDailyRecord::from)
                    .collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}
// ========================== End ==========================

// ========================== Period Settings Start ========================
#[tauri::command]
pub async fn period_settings_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<PeriodSettings>, String> {
    let service = get_settings_service();
    Ok(ApiResponse::from_result(
        service
            .period_settings_get(&state.db, serial_num)
            .await
            .map(PeriodSettings::from),
    ))
}

#[tauri::command]
pub async fn period_settings_create(
    state: State<'_, AppState>,
    data: PeriodSettingsCreate,
) -> Result<ApiResponse<PeriodSettings>, String> {
    let service = get_settings_service();
    Ok(ApiResponse::from_result(
        service
            .period_settings_create(&state.db, data)
            .await
            .map(PeriodSettings::from),
    ))
}

#[tauri::command]
pub async fn period_settings_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: PeriodSettingsUpdate,
) -> Result<ApiResponse<PeriodSettings>, String> {
    let service = get_settings_service();
    Ok(ApiResponse::from_result(
        service
            .period_settings_update(&state.db, serial_num, data)
            .await
            .map(PeriodSettings::from),
    ))
}
// ========================== Period Settings End ==========================
