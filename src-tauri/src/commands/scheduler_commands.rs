// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           scheduler_commands.rs
// Description:    调度器配置相关 Tauri 命令
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use common::{
    AppState, SchedulerConfigCreateRequest, SchedulerConfigResponse, SchedulerConfigService,
    SchedulerConfigUpdateRequest,
};
use tauri::State;

/// 获取调度器配置
///
/// # Arguments
/// * `state` - 应用状态
/// * `task_type` - 任务类型
/// * `user_id` - 用户ID（可选）
///
/// # Returns
/// * `Result<SchedulerConfigResponse, String>` - 配置信息
#[tauri::command]
pub async fn scheduler_config_get(
    state: State<'_, AppState>,
    task_type: String,
    user_id: Option<String>,
) -> Result<SchedulerConfigResponse, String> {
    tracing::debug!("获取调度器配置: task={}, user={:?}", task_type, user_id);

    let service = SchedulerConfigService::new();

    let _config = service
        .get_config(&state.db, &task_type, user_id.as_deref())
        .await
        .map_err(|e| e.to_string())?;

    // 查询数据库中的完整配置（用于返回详细信息）
    let configs = service
        .list_configs(&state.db, user_id.as_deref())
        .await
        .map_err(|e| e.to_string())?;

    // 查找匹配的配置
    if let Some(model) = configs.into_iter().find(|c| c.task_type == task_type) {
        Ok(SchedulerConfigResponse::from(model))
    } else {
        // 如果数据库没有，返回默认配置的响应格式
        let default_config = SchedulerConfigService::default_config(&task_type);
        Ok(SchedulerConfigResponse {
            serial_num: format!("default-{}", task_type),
            user_serial_num: user_id,
            task_type: default_config.task_type,
            enabled: default_config.enabled,
            interval_seconds: default_config.interval.as_secs() as i32,
            max_retry_count: default_config.max_retry_count,
            retry_delay_seconds: default_config.retry_delay.as_secs() as i32,
            platform: default_config.platform,
            battery_threshold: default_config.battery_threshold,
            network_required: default_config.network_required,
            wifi_only: default_config.wifi_only,
            active_hours_start: default_config.active_hours.map(|(s, _)| s.to_string()),
            active_hours_end: default_config.active_hours.map(|(_, e)| e.to_string()),
            priority: default_config.priority,
            description: None,
            is_default: true,
            created_at: chrono::Local::now().to_string(),
            updated_at: chrono::Local::now().to_string(),
        })
    }
}

/// 获取调度器配置列表
///
/// # Arguments
/// * `state` - 应用状态
/// * `user_id` - 用户ID（可选）
///
/// # Returns
/// * `Result<Vec<SchedulerConfigResponse>, String>` - 配置列表
#[tauri::command]
pub async fn scheduler_config_list(
    state: State<'_, AppState>,
    user_id: Option<String>,
) -> Result<Vec<SchedulerConfigResponse>, String> {
    tracing::debug!("获取调度器配置列表: user={:?}", user_id);

    let service = SchedulerConfigService::new();

    let configs = service
        .list_configs(&state.db, user_id.as_deref())
        .await
        .map_err(|e| e.to_string())?;

    let responses = configs
        .into_iter()
        .map(SchedulerConfigResponse::from)
        .collect();

    Ok(responses)
}

/// 更新调度器配置
///
/// # Arguments
/// * `state` - 应用状态
/// * `request` - 更新请求
///
/// # Returns
/// * `Result<SchedulerConfigResponse, String>` - 更新后的配置
#[tauri::command]
pub async fn scheduler_config_update(
    state: State<'_, AppState>,
    request: SchedulerConfigUpdateRequest,
) -> Result<SchedulerConfigResponse, String> {
    tracing::debug!("更新调度器配置: {:?}", request.serial_num);

    let service = SchedulerConfigService::new();

    // 解析时间字符串
    let active_hours_start = request
        .active_hours_start
        .as_ref()
        .and_then(|s| chrono::NaiveTime::parse_from_str(s, "%H:%M:%S").ok());

    let active_hours_end = request
        .active_hours_end
        .as_ref()
        .and_then(|s| chrono::NaiveTime::parse_from_str(s, "%H:%M:%S").ok());

    let updated = service
        .update_config(
            &state.db,
            request.serial_num,
            request.enabled,
            request.interval_seconds,
            request.max_retry_count,
            request.retry_delay_seconds,
            request.battery_threshold,
            request.network_required,
            request.wifi_only,
            active_hours_start,
            active_hours_end,
            request.priority,
            request.description,
        )
        .await
        .map_err(|e| e.to_string())?;

    Ok(SchedulerConfigResponse::from(updated))
}

/// 创建调度器配置
///
/// # Arguments
/// * `state` - 应用状态
/// * `request` - 创建请求
///
/// # Returns
/// * `Result<SchedulerConfigResponse, String>` - 创建的配置
#[tauri::command]
pub async fn scheduler_config_create(
    state: State<'_, AppState>,
    request: SchedulerConfigCreateRequest,
) -> Result<SchedulerConfigResponse, String> {
    tracing::debug!("创建调度器配置: task={}", request.task_type);

    let service = SchedulerConfigService::new();

    // 解析时间字符串
    let active_hours_start = request
        .active_hours_start
        .as_ref()
        .and_then(|s| chrono::NaiveTime::parse_from_str(s, "%H:%M:%S").ok());

    let active_hours_end = request
        .active_hours_end
        .as_ref()
        .and_then(|s| chrono::NaiveTime::parse_from_str(s, "%H:%M:%S").ok());

    let created = service
        .create_config(
            &state.db,
            request.user_serial_num,
            request.task_type,
            request.enabled,
            request.interval_seconds,
            request.platform,
            request.max_retry_count,
            request.retry_delay_seconds,
            request.battery_threshold,
            request.network_required,
            request.wifi_only,
            active_hours_start,
            active_hours_end,
            request.priority,
            request.description,
        )
        .await
        .map_err(|e| e.to_string())?;

    Ok(SchedulerConfigResponse::from(created))
}

/// 删除调度器配置
///
/// # Arguments
/// * `state` - 应用状态
/// * `serial_num` - 配置ID
///
/// # Returns
/// * `Result<(), String>` - 删除结果
#[tauri::command]
pub async fn scheduler_config_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<(), String> {
    tracing::debug!("删除调度器配置: {}", serial_num);

    let service = SchedulerConfigService::new();

    service
        .delete_config(&state.db, &serial_num)
        .await
        .map_err(|e| e.to_string())?;

    Ok(())
}

/// 重置调度器配置到默认值
///
/// # Arguments
/// * `state` - 应用状态
/// * `task_type` - 任务类型
/// * `user_id` - 用户ID（可选）
///
/// # Returns
/// * `Result<(), String>` - 重置结果
#[tauri::command]
pub async fn scheduler_config_reset(
    state: State<'_, AppState>,
    task_type: String,
    user_id: Option<String>,
) -> Result<(), String> {
    tracing::debug!("重置调度器配置: task={}, user={:?}", task_type, user_id);

    use entity::scheduler_config;
    use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};

    let service = SchedulerConfigService::new();

    // 删除用户配置
    let mut query = scheduler_config::Entity::delete_many()
        .filter(scheduler_config::Column::TaskType.eq(&task_type));

    if let Some(uid) = user_id {
        query = query.filter(scheduler_config::Column::UserSerialNum.eq(uid));
    } else {
        query = query.filter(scheduler_config::Column::UserSerialNum.is_null());
    }

    query
        .exec(state.db.as_ref())
        .await
        .map_err(|e| e.to_string())?;

    // 清除缓存
    service.clear_cache().await;

    tracing::info!("配置已重置: task={}", task_type);
    Ok(())
}

/// 清除配置缓存
///
/// # Arguments
/// * `state` - 应用状态
///
/// # Returns
/// * `Result<(), String>` - 清除结果
#[tauri::command]
pub async fn scheduler_config_clear_cache(_state: State<'_, AppState>) -> Result<(), String> {
    tracing::debug!("清除调度器配置缓存");

    let service = SchedulerConfigService::new();
    service.clear_cache().await;

    Ok(())
}
