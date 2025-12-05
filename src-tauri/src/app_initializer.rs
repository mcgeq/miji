// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           app_initializer.rs
// Description:    应用初始化器 - 统一管理应用启动流程
// Create   Date:  2025-11-11
// -----------------------------------------------------------------------------

use crate::default_account::create_default_virtual_account;
use crate::default_user::create_default_user;
use crate::scheduler_manager::SchedulerManager;
use common::{
    config::Config, error::AppError, business_code::BusinessCode, ApiCredentials, AppState,
    SetupState,
};
use migration::{Migrator, MigratorTrait};
use sea_orm::DatabaseConnection;
use std::sync::Arc;
use tauri::{AppHandle, Manager};
use tokio::sync::Mutex;
use tokio::time::{sleep, Duration};

/// 应用初始化器
pub struct AppInitializer {
    app_handle: AppHandle,
}

impl AppInitializer {
    /// 创建新的初始化器
    pub fn new(app_handle: AppHandle) -> Self {
        Self { app_handle }
    }

    /// 执行完整的初始化流程
    pub async fn initialize(&self) -> Result<AppState, AppError> {
        log::info!("开始应用初始化...");

        // 1. 初始化配置
        let config = self.initialize_config()?;
        log::info!("✓ 配置初始化完成");

        // 2. 初始化数据库
        let db = self.initialize_database(&config.db_url).await?;
        log::info!("✓ 数据库初始化完成");

        // 3. 创建应用状态
        let app_state = self.create_app_state(db, config)?;
        log::info!("✓ 应用状态创建完成");

        log::info!("应用初始化成功！");
        Ok(app_state)
    }

    /// 初始化配置
    fn initialize_config(&self) -> Result<&'static Config, AppError> {
        Config::init(&self.app_handle)?;
        Ok(Config::get())
    }

    /// 初始化数据库连接和迁移
    async fn initialize_database(&self, db_url: &str) -> Result<DatabaseConnection, AppError> {
        // 连接数据库
        let db = sea_orm::Database::connect(db_url)
            .await
            .map_err(|e| {
                AppError::simple(
                    BusinessCode::DatabaseError,
                    format!("数据库连接失败: {e}"),
                )
            })?;

        // 执行数据库迁移
        Migrator::up(&db, None).await.map_err(|e| {
            AppError::simple(
                BusinessCode::DatabaseError,
                format!("数据库迁移失败: {e}"),
            )
        })?;

        Ok(db)
    }

    /// 创建应用状态
    fn create_app_state(
        &self,
        db: DatabaseConnection,
        config: &Config,
    ) -> Result<AppState, AppError> {
        let credentials = ApiCredentials {
            jwt_secret: config.jwt_secret.clone(),
            expired_at: config.expired_at,
        };

        Ok(AppState {
            db: Arc::new(db),
            credentials: Arc::new(Mutex::new(credentials)),
            task: Arc::new(Mutex::new(SetupState {
                frontend_task: false,
                backend_task: true,
            })),
        })
    }

    /// 执行后台启动任务（异步）
    pub async fn run_background_setup(app_handle: AppHandle) -> Result<(), ()> {
        // 根据平台调整初始化延迟
        #[cfg(any(target_os = "android", target_os = "ios"))]
        {
            log::info!("执行移动端后台设置任务...");
            sleep(Duration::from_millis(500)).await;
        }

        #[cfg(not(any(target_os = "android", target_os = "ios")))]
        {
            log::info!("执行桌面端后台设置任务...");
            sleep(Duration::from_secs(3)).await;
        }

        let app_state = app_handle.state::<AppState>();

        // 创建默认用户
        if let Err(e) = create_default_user(&app_state.db).await {
            log::error!("创建默认用户失败: {}", e);
        } else {
            log::info!("✓ 默认用户创建完成");
        }

        // 创建默认虚拟账户
        if let Err(e) = create_default_virtual_account(&app_state.db).await {
            log::error!("创建默认虚拟账户失败: {}", e);
        } else {
            log::info!("✓ 默认虚拟账户创建完成");
        }

        // 初始化移动端通知（Android 渠道，iOS 配置）
        #[cfg(any(target_os = "android", target_os = "ios"))]
        {
            use crate::mobiles::notification_setup;
            log::info!("🔔 开始初始化移动端通知...");
            match notification_setup::setup_mobile_notifications(&app_handle) {
                Ok(_) => {
                    log::info!("✓ 移动端通知初始化完成");
                }
                Err(e) => {
                    log::error!("❌ 移动端通知初始化失败: {}", e);
                    // 不中断启动流程，继续执行
                }
            }
        }

        // 启动定时任务调度器
        let scheduler = SchedulerManager::new();
        scheduler.start_all(app_handle.clone()).await;
        log::info!("✓ 定时任务调度器启动完成");

        log::info!("后台设置任务完成！");

        // 设置后端任务为完成状态
        use crate::commands::set_complete;
        set_complete(app_handle.clone(), app_handle.state::<AppState>(), "backend".to_string())
            .await?;

        Ok(())
    }
}
