// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           scheduler_config.rs
// Description:    调度器配置相关 DTO
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use serde::{Deserialize, Serialize};

/// 调度器配置响应
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SchedulerConfigResponse {
    pub serial_num: String,
    pub user_serial_num: Option<String>,
    pub task_type: String,
    pub enabled: bool,
    pub interval_seconds: i32,
    pub max_retry_count: i32,
    pub retry_delay_seconds: i32,
    pub platform: Option<String>,
    pub battery_threshold: Option<i32>,
    pub network_required: bool,
    pub wifi_only: bool,
    pub active_hours_start: Option<String>,
    pub active_hours_end: Option<String>,
    pub priority: i32,
    pub description: Option<String>,
    pub is_default: bool,
    pub created_at: String,
    pub updated_at: String,
}

/// 调度器配置更新请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SchedulerConfigUpdateRequest {
    pub serial_num: String,
    pub enabled: Option<bool>,
    pub interval_seconds: Option<i32>,
    pub max_retry_count: Option<i32>,
    pub retry_delay_seconds: Option<i32>,
    pub battery_threshold: Option<i32>,
    pub network_required: Option<bool>,
    pub wifi_only: Option<bool>,
    pub active_hours_start: Option<String>,
    pub active_hours_end: Option<String>,
    pub priority: Option<i32>,
    pub description: Option<String>,
}

/// 调度器配置创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SchedulerConfigCreateRequest {
    pub user_serial_num: Option<String>,
    pub task_type: String,
    pub enabled: bool,
    pub interval_seconds: i32,
    pub platform: Option<String>,
    pub max_retry_count: Option<i32>,
    pub retry_delay_seconds: Option<i32>,
    pub battery_threshold: Option<i32>,
    pub network_required: Option<bool>,
    pub wifi_only: Option<bool>,
    pub active_hours_start: Option<String>,
    pub active_hours_end: Option<String>,
    pub priority: Option<i32>,
    pub description: Option<String>,
}

impl From<::entity::scheduler_config::Model> for SchedulerConfigResponse {
    fn from(model: ::entity::scheduler_config::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            user_serial_num: model.user_serial_num,
            task_type: model.task_type,
            enabled: model.enabled,
            interval_seconds: model.interval_seconds,
            max_retry_count: model.max_retry_count.unwrap_or(3),
            retry_delay_seconds: model.retry_delay_seconds.unwrap_or(60),
            platform: model.platform,
            battery_threshold: model.battery_threshold,
            network_required: model.network_required,
            wifi_only: model.wifi_only,
            active_hours_start: model.active_hours_start.map(|t| t.to_string()),
            active_hours_end: model.active_hours_end.map(|t| t.to_string()),
            priority: model.priority,
            description: model.description,
            is_default: model.is_default,
            created_at: model.created_at.to_string(),
            updated_at: model.updated_at.to_string(),
        }
    }
}
