// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           scheduler_config_service.rs
// Description:    调度器配置服务
// Create   Date:  2025-12-06
// -----------------------------------------------------------------------------

use crate::{AppError, BusinessCode, MijiResult};
use ::entity::scheduler_config;
use sea_orm::{ActiveModelTrait, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, Set};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio::time::Duration;

/// 调度器配置
#[derive(Debug, Clone)]
pub struct SchedulerConfig {
    pub task_type: String,
    pub enabled: bool,
    pub interval: Duration,
    pub max_retry_count: i32,
    pub retry_delay: Duration,
    pub platform: Option<String>,
    pub battery_threshold: Option<i32>,
    pub network_required: bool,
    pub wifi_only: bool,
    pub active_hours: Option<(chrono::NaiveTime, chrono::NaiveTime)>,
    pub priority: i32,
}

/// 调度器配置服务
pub struct SchedulerConfigService {
    /// 配置缓存
    cache: Arc<RwLock<HashMap<String, SchedulerConfig>>>,
}

impl SchedulerConfigService {
    /// 创建新的配置服务
    pub fn new() -> Self {
        Self {
            cache: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// 获取任务配置（带缓存）
    ///
    /// 优先级: 用户配置 > 平台配置 > 全局配置 > 默认配置
    ///
    /// # Arguments
    /// * `db` - 数据库连接
    /// * `task_type` - 任务类型
    /// * `user_id` - 用户ID（None 表示全局配置）
    ///
    /// # Returns
    /// * `MijiResult<SchedulerConfig>` - 配置信息
    pub async fn get_config(
        &self,
        db: &DatabaseConnection,
        task_type: &str,
        user_id: Option<&str>,
    ) -> MijiResult<SchedulerConfig> {
        // 构建缓存键
        let cache_key = format!("{}:{}", task_type, user_id.unwrap_or("global"));

        // 尝试从缓存读取
        {
            let cache = self.cache.read().await;
            if let Some(config) = cache.get(&cache_key) {
                tracing::debug!("从缓存读取配置: {}", cache_key);
                return Ok(config.clone());
            }
        }

        // 查询数据库
        let config = self.query_config(db, task_type, user_id).await?;

        // 写入缓存
        {
            let mut cache = self.cache.write().await;
            cache.insert(cache_key.clone(), config.clone());
            tracing::debug!("配置写入缓存: {}", cache_key);
        }

        Ok(config)
    }

    /// 从数据库查询配置
    async fn query_config(
        &self,
        db: &DatabaseConnection,
        task_type: &str,
        user_id: Option<&str>,
    ) -> MijiResult<SchedulerConfig> {
        // 当前平台
        let platform = Self::current_platform();

        // 查询优先级顺序
        let queries = vec![
            // 1. 用户 + 平台特定配置
            (user_id, Some(platform.as_str())),
            // 2. 用户 + 全平台配置
            (user_id, None),
            // 3. 全局 + 平台特定配置
            (None, Some(platform.as_str())),
            // 4. 全局 + 全平台配置
            (None, None),
        ];

        for (uid, plat) in queries {
            let mut query = scheduler_config::Entity::find()
                .filter(scheduler_config::Column::TaskType.eq(task_type));

            if let Some(u) = uid {
                query = query.filter(scheduler_config::Column::UserSerialNum.eq(u));
            } else {
                query = query.filter(scheduler_config::Column::UserSerialNum.is_null());
            }

            if let Some(p) = plat {
                query = query.filter(scheduler_config::Column::Platform.eq(p));
            } else {
                query = query.filter(scheduler_config::Column::Platform.is_null());
            }

            if let Some(model) = query.one(db).await? {
                tracing::debug!(
                    "从数据库读取配置: task={}, user={:?}, platform={:?}",
                    task_type,
                    uid,
                    plat
                );
                return Ok(Self::model_to_config(model));
            }
        }

        // 如果数据库没有配置，返回默认配置
        tracing::debug!("使用默认配置: task={}", task_type);
        Ok(Self::default_config(task_type))
    }

    /// 模型转配置
    fn model_to_config(model: scheduler_config::Model) -> SchedulerConfig {
        SchedulerConfig {
            task_type: model.task_type,
            enabled: model.enabled,
            interval: Duration::from_secs(model.interval_seconds as u64),
            max_retry_count: model.max_retry_count.unwrap_or(3),
            retry_delay: Duration::from_secs(model.retry_delay_seconds.unwrap_or(60) as u64),
            platform: model.platform,
            battery_threshold: model.battery_threshold,
            network_required: model.network_required,
            wifi_only: model.wifi_only,
            active_hours: model
                .active_hours_start
                .zip(model.active_hours_end)
                .map(|(start, end)| (start, end)),
            priority: model.priority,
        }
    }

    /// 获取默认配置
    pub fn default_config(task_type: &str) -> SchedulerConfig {
        let interval = match task_type {
            "TransactionProcess" => 7200,
            "TodoAutoCreate" => 7200,
            "TodoReminderCheck" => {
                if cfg!(any(target_os = "android", target_os = "ios")) {
                    300 // 移动端 5 分钟
                } else {
                    60 // 桌面端 1 分钟
                }
            }
            "BillReminderCheck" => {
                if cfg!(any(target_os = "android", target_os = "ios")) {
                    300 // 移动端 5 分钟
                } else {
                    60 // 桌面端 1 分钟
                }
            }
            "PeriodReminderCheck" => 86400, // 1 天
            "BudgetAutoCreate" => 7200,     // 2 小时
            _ => 3600,                      // 默认 1 小时
        };

        SchedulerConfig {
            task_type: task_type.to_string(),
            enabled: true,
            interval: Duration::from_secs(interval),
            max_retry_count: 3,
            retry_delay: Duration::from_secs(60),
            platform: None,
            battery_threshold: Some(20), // 移动端默认20%电量阈值
            network_required: false,
            wifi_only: false,
            active_hours: None,
            priority: 5,
        }
    }

    /// 获取当前平台
    fn current_platform() -> String {
        if cfg!(target_os = "android") {
            "android".to_string()
        } else if cfg!(target_os = "ios") {
            "ios".to_string()
        } else if cfg!(any(target_os = "android", target_os = "ios")) {
            "mobile".to_string()
        } else {
            "desktop".to_string()
        }
    }

    /// 清除缓存
    pub async fn clear_cache(&self) {
        let mut cache = self.cache.write().await;
        cache.clear();
        tracing::debug!("配置缓存已清除");
    }

    /// 清除特定任务的缓存
    pub async fn clear_task_cache(&self, task_type: &str) {
        let mut cache = self.cache.write().await;
        cache.retain(|key, _| !key.starts_with(&format!("{}:", task_type)));
        tracing::debug!("清除任务缓存: {}", task_type);
    }

    /// 更新配置
    ///
    /// # Arguments
    /// * `db` - 数据库连接
    /// * `serial_num` - 配置ID
    /// * `enabled` - 是否启用
    /// * `interval_seconds` - 执行间隔
    /// * 其他可选参数...
    ///
    /// # Returns
    /// * `MijiResult<scheduler_config::Model>` - 更新后的配置
    pub async fn update_config(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        enabled: Option<bool>,
        interval_seconds: Option<i32>,
        max_retry_count: Option<i32>,
        retry_delay_seconds: Option<i32>,
        battery_threshold: Option<i32>,
        network_required: Option<bool>,
        wifi_only: Option<bool>,
        active_hours_start: Option<chrono::NaiveTime>,
        active_hours_end: Option<chrono::NaiveTime>,
        priority: Option<i32>,
        description: Option<String>,
    ) -> MijiResult<scheduler_config::Model> {
        use crate::utils::date::DateUtils;

        // 查询现有配置
        let config = scheduler_config::Entity::find_by_id(&serial_num)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "配置不存在"))?;

        // 更新配置
        let mut active: scheduler_config::ActiveModel = config.into();

        if let Some(e) = enabled {
            active.enabled = Set(e);
        }
        if let Some(i) = interval_seconds {
            active.interval_seconds = Set(i);
        }
        if let Some(m) = max_retry_count {
            active.max_retry_count = Set(Some(m));
        }
        if let Some(r) = retry_delay_seconds {
            active.retry_delay_seconds = Set(Some(r));
        }
        if let Some(b) = battery_threshold {
            active.battery_threshold = Set(Some(b));
        }
        if let Some(n) = network_required {
            active.network_required = Set(n);
        }
        if let Some(w) = wifi_only {
            active.wifi_only = Set(w);
        }
        if let Some(s) = active_hours_start {
            active.active_hours_start = Set(Some(s));
        }
        if let Some(e) = active_hours_end {
            active.active_hours_end = Set(Some(e));
        }
        if let Some(p) = priority {
            active.priority = Set(p);
        }
        if let Some(d) = description {
            active.description = Set(Some(d));
        }

        active.updated_at = Set(DateUtils::local_now());

        let updated = active.update(db).await?;

        // 清除相关缓存
        self.clear_cache().await;

        tracing::info!("配置已更新: {}", serial_num);
        Ok(updated)
    }

    /// 创建新配置
    pub async fn create_config(
        &self,
        db: &DatabaseConnection,
        user_serial_num: Option<String>,
        task_type: String,
        enabled: bool,
        interval_seconds: i32,
        platform: Option<String>,
        max_retry_count: Option<i32>,
        retry_delay_seconds: Option<i32>,
        battery_threshold: Option<i32>,
        network_required: Option<bool>,
        wifi_only: Option<bool>,
        active_hours_start: Option<chrono::NaiveTime>,
        active_hours_end: Option<chrono::NaiveTime>,
        priority: Option<i32>,
        description: Option<String>,
    ) -> MijiResult<scheduler_config::Model> {
        use crate::utils::{date::DateUtils, uuid::McgUuid};

        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38);

        let config = scheduler_config::ActiveModel {
            serial_num: Set(serial_num),
            user_serial_num: Set(user_serial_num),
            task_type: Set(task_type),
            enabled: Set(enabled),
            interval_seconds: Set(interval_seconds),
            max_retry_count: Set(max_retry_count),
            retry_delay_seconds: Set(retry_delay_seconds),
            platform: Set(platform),
            battery_threshold: Set(battery_threshold),
            network_required: Set(network_required.unwrap_or(false)),
            wifi_only: Set(wifi_only.unwrap_or(false)),
            active_hours_start: Set(active_hours_start),
            active_hours_end: Set(active_hours_end),
            priority: Set(priority.unwrap_or(5)),
            description: Set(description),
            is_default: Set(false),
            created_at: Set(now),
            updated_at: Set(now),
        };

        let created = config.insert(db).await?;

        // 清除缓存
        self.clear_cache().await;

        tracing::info!("配置已创建: {}", created.serial_num);
        Ok(created)
    }

    /// 删除配置
    pub async fn delete_config(&self, db: &DatabaseConnection, serial_num: &str) -> MijiResult<()> {
        scheduler_config::Entity::delete_by_id(serial_num)
            .exec(db)
            .await?;

        // 清除缓存
        self.clear_cache().await;

        tracing::info!("配置已删除: {}", serial_num);
        Ok(())
    }

    /// 获取所有配置
    pub async fn list_configs(
        &self,
        db: &DatabaseConnection,
        user_id: Option<&str>,
    ) -> MijiResult<Vec<scheduler_config::Model>> {
        let mut query = scheduler_config::Entity::find();

        if let Some(uid) = user_id {
            query = query.filter(scheduler_config::Column::UserSerialNum.eq(uid));
        } else {
            query = query.filter(scheduler_config::Column::UserSerialNum.is_null());
        }

        let configs = query.all(db).await?;
        Ok(configs)
    }
}

impl Default for SchedulerConfigService {
    fn default() -> Self {
        Self::new()
    }
}
