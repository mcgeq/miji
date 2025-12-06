use serde::{Deserialize, Serialize};
use tauri::Manager;
pub mod logging;

/// 分期处理完成事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallmentProcessedEvent {
    pub processed_count: usize,
    pub timestamp: i64,
}

/// 分期处理失败事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallmentProcessFailedEvent {
    pub error: String,
    pub timestamp: i64,
}

// 模块声明
#[cfg(desktop)]
mod desktops;
#[cfg(any(target_os = "android", target_os = "ios"))]
mod mobiles;

mod app_initializer;
mod commands;
mod default_account;
mod default_user;
mod plugins;
mod scheduler_manager;
mod system_commands;
#[cfg(desktop)]
mod tray_manager;

#[cfg(desktop)]
use desktops::init;
#[cfg(desktop)]
use init::MijiInit;

#[cfg(any(target_os = "android", target_os = "ios"))]
use init::MijiInit;
#[cfg(any(target_os = "android", target_os = "ios"))]
use mobiles::init;

use crate::commands::AppPreferences;
use app_initializer::AppInitializer;
use commands::init_commands;
use dotenvy::dotenv;
use plugins::generic_plugins;

#[cfg(desktop)]
use tray_manager::{create_system_tray, setup_window_close_handler};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    dotenv().ok();
    let builder = tauri::Builder::default();

    let builder = generic_plugins(builder);

    #[cfg(desktop)]
    let builder = builder.init_plugin();

    #[cfg(any(target_os = "android", target_os = "ios"))]
    let builder = builder.init_plugin();

    let builder = init_commands(builder);

    builder
        .setup(|app| {
            let app_handle = app.handle();

            // 使用新的初始化器执行初始化
            let initializer = AppInitializer::new(app_handle.clone());
            let app_state =
                tauri::async_runtime::block_on(async { initializer.initialize().await })?;

            // 管理应用状态
            app.manage(app_state);

            // 管理用户偏好设置
            app.manage(AppPreferences::new(std::collections::HashMap::new()));

            // 桌面平台特定初始化
            #[cfg(desktop)]
            {
                create_system_tray(app_handle)?;
                setup_window_close_handler(app_handle)?;
            }

            // 启动后台任务
            let background_handle = app_handle.clone();
            tauri::async_runtime::spawn(async move {
                AppInitializer::run_background_setup(background_handle).await
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
