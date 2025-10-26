use common::{
    ApiResponse, AppState,
    paginations::{PagedQuery, PagedResult},
};
use tauri::State;
use tracing::{info, error, instrument};

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
#[instrument(skip(state), fields(record_serial_num = %serial_num))]
pub async fn period_record_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<PeriodRecords>, String> {
    let service = get_period_record_service();
    
    match service.period_record_get(&state.db, serial_num.clone()).await {
        Ok(result) => {
            info!(
                record_serial_num = %result.serial_num,
                "获取月经记录成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodRecords::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                record_serial_num = %serial_num,
                "获取月经记录失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn period_record_create(
    state: State<'_, AppState>,
    data: PeriodRecordsCreate,
) -> Result<ApiResponse<PeriodRecords>, String> {
    info!("开始创建月经记录");
    
    let service = get_period_record_service();
    
    match service.period_record_create(&state.db, data).await {
        Ok(result) => {
            info!(
                record_serial_num = %result.serial_num,
                "月经记录创建成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodRecords::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                "月经记录创建失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(record_serial_num = %serial_num))]
pub async fn period_record_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: PeriodRecordsUpdate,
) -> Result<ApiResponse<PeriodRecords>, String> {
    info!(
        record_serial_num = %serial_num,
        "开始更新月经记录"
    );
    
    let service = get_period_record_service();
    
    match service.period_record_update(&state.db, serial_num.clone(), data).await {
        Ok(result) => {
            info!(
                record_serial_num = %result.serial_num,
                "月经记录更新成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodRecords::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                record_serial_num = %serial_num,
                "月经记录更新失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(record_serial_num = %serial_num))]
pub async fn period_record_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        record_serial_num = %serial_num,
        "开始删除月经记录"
    );
    
    let service = get_period_record_service();
    
    match service.period_record_delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(
                record_serial_num = %serial_num,
                "月经记录删除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                record_serial_num = %serial_num,
                "月经记录删除失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn period_record_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<PeriodRecordFilter>,
) -> Result<ApiResponse<PagedResult<PeriodRecords>>, String> {
    let service = get_period_record_service();
    
    match service.period_record_list_paged(&state.db, query).await {
        Ok(paged) => {
            info!(
                total_count = paged.total_count,
                current_page = paged.current_page,
                page_size = paged.page_size,
                "分页列出月经记录成功"
            );
            Ok(ApiResponse::from_result(Ok(PagedResult {
                rows: paged.rows.into_iter().map(PeriodRecords::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            })))
        }
        Err(e) => {
            error!(
                error = %e,
                "分页列出月经记录失败"
            );
            Err(e.to_string())
        }
    }
}
// ========================== End ==========================

// ========================== Start ==========================
#[tauri::command]
#[instrument(skip(state), fields(daily_record_serial_num = %serial_num))]
pub async fn period_daily_record_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<PeriodDailyRecord>, String> {
    let service = get_period_daily_record_service();
    
    match service.period_daily_record_get(&state.db, serial_num.clone()).await {
        Ok(result) => {
            info!(
                daily_record_serial_num = %result.period_daily_record.serial_num,
                "获取每日记录成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodDailyRecord::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                daily_record_serial_num = %serial_num,
                "获取每日记录失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn period_daily_record_create(
    state: State<'_, AppState>,
    data: PeriodDailyRecordCreate,
) -> Result<ApiResponse<PeriodDailyRecord>, String> {
    info!("开始创建每日记录");
    
    let service = get_period_daily_record_service();
    
    match service.period_daily_record_create(&state.db, data).await {
        Ok(result) => {
            info!(
                daily_record_serial_num = %result.period_daily_record.serial_num,
                "每日记录创建成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodDailyRecord::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                "每日记录创建失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(daily_record_serial_num = %serial_num))]
pub async fn period_daily_record_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: PeriodDailyRecordUpdate,
) -> Result<ApiResponse<PeriodDailyRecord>, String> {
    info!(
        daily_record_serial_num = %serial_num,
        "开始更新每日记录"
    );
    
    let service = get_period_daily_record_service();
    
    match service.period_daily_record_update(&state.db, serial_num.clone(), data).await {
        Ok(result) => {
            info!(
                daily_record_serial_num = %result.period_daily_record.serial_num,
                "每日记录更新成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodDailyRecord::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                daily_record_serial_num = %serial_num,
                "每日记录更新失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(daily_record_serial_num = %serial_num))]
pub async fn period_daily_record_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        daily_record_serial_num = %serial_num,
        "开始删除每日记录"
    );
    
    let service = get_period_daily_record_service();
    
    match service.period_daily_record_delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(
                daily_record_serial_num = %serial_num,
                "每日记录删除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                daily_record_serial_num = %serial_num,
                "每日记录删除失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn period_daily_record_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<PeriodDailyRecordFilter>,
) -> Result<ApiResponse<PagedResult<PeriodDailyRecord>>, String> {
    let service = get_period_daily_record_service();
    
    match service.period_daily_record_list_paged(&state.db, query).await {
        Ok(paged) => {
            info!(
                total_count = paged.total_count,
                current_page = paged.current_page,
                page_size = paged.page_size,
                "分页列出每日记录成功"
            );
            Ok(ApiResponse::from_result(Ok(PagedResult {
                rows: paged
                    .rows
                    .into_iter()
                    .map(PeriodDailyRecord::from)
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
                "分页列出每日记录失败"
            );
            Err(e.to_string())
        }
    }
}
// ========================== End ==========================

// ========================== Period Settings Start ========================
#[tauri::command]
#[instrument(skip(state), fields(settings_serial_num = %serial_num))]
pub async fn period_settings_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<PeriodSettings>, String> {
    let service = get_settings_service();
    
    match service.period_settings_get(&state.db, serial_num.clone()).await {
        Ok(result) => {
            info!(
                settings_serial_num = %result.serial_num,
                "获取月经设置成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodSettings::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                settings_serial_num = %serial_num,
                "获取月经设置失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn period_settings_create(
    state: State<'_, AppState>,
    data: PeriodSettingsCreate,
) -> Result<ApiResponse<PeriodSettings>, String> {
    info!("开始创建月经设置");
    
    let service = get_settings_service();
    
    match service.period_settings_create(&state.db, data).await {
        Ok(result) => {
            info!(
                settings_serial_num = %result.serial_num,
                "月经设置创建成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodSettings::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                "月经设置创建失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(settings_serial_num = %serial_num))]
pub async fn period_settings_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: PeriodSettingsUpdate,
) -> Result<ApiResponse<PeriodSettings>, String> {
    info!(
        settings_serial_num = %serial_num,
        "开始更新月经设置"
    );
    
    let service = get_settings_service();
    
    match service.period_settings_update(&state.db, serial_num.clone(), data).await {
        Ok(result) => {
            info!(
                settings_serial_num = %result.serial_num,
                "月经设置更新成功"
            );
            Ok(ApiResponse::from_result(Ok(PeriodSettings::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                settings_serial_num = %serial_num,
                "月经设置更新失败"
            );
            Err(e.to_string())
        }
    }
}
// ========================== Period Settings End ==========================
