use migration::{Migrator, MigratorTrait};
use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Manager};

#[cfg(desktop)]
use tauri::{
    Emitter, WindowEvent,
    menu::{MenuBuilder, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
};

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

#[cfg(desktop)]
mod desktops;

mod commands;
mod default_user;
#[cfg(any(target_os = "android", target_os = "ios"))]
mod mobiles;
mod plugins;

#[cfg(desktop)]
use desktops::init;
#[cfg(desktop)]
use init::MijiInit;

#[cfg(any(target_os = "android", target_os = "ios"))]
use init::MijiInit;
#[cfg(any(target_os = "android", target_os = "ios"))]
use mobiles::init;

use commands::init_commands;
use common::{
    ApiCredentials, AppState, SetupState, business_code::BusinessCode, config::Config,
    error::AppError,
};
use dotenvy::dotenv;
use plugins::generic_plugins;
use std::sync::Arc;
use tokio::{
    sync::Mutex,
    time::{Duration, sleep},
};

use crate::commands::{AppPreferences, set_complete};
use crate::default_user::create_default_user;

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
            // 1. 获取 AppHandle
            let app_handle = app.handle();

            #[cfg(desktop)] // 只在桌面平台执行
            let cloned_handle = app_handle.clone();
            // 2. 加载配置
            Config::init(app_handle)?;
            let config = Config::get();

            // 3. 创建 API 凭证
            let credentials = ApiCredentials {
                jwt_secret: config.jwt_secret.clone(),
                expired_at: config.expired_at,
            };

            // 4. 初始化数据库连接
            // 使用 tauri 的异步运行时执行数据库连接
            let db = tauri::async_runtime::block_on(async {
                sea_orm::Database::connect(&config.db_url).await
            })
            .map_err(|e| {
                AppError::simple(
                    BusinessCode::DatabaseError,
                    format!("Database connection failed: {e}"),
                )
            })?;
            tauri::async_runtime::block_on(async { Migrator::up(&db, None).await }).map_err(
                |e| {
                    AppError::simple(
                        BusinessCode::DatabaseError,
                        format!("Database migration failed: {e}"),
                    )
                },
            )?;

            let db = Arc::new(db);

            // 5. 创建应用状态
            let app_state = AppState {
                db,
                credentials: Arc::new(Mutex::new(credentials)),
                task: Arc::new(Mutex::new(SetupState {
                    frontend_task: false,
                    backend_task: true,
                })),
            };

            // 6. 管理应用状态
            app.manage(app_state.clone());

            // 7. 管理用户偏好设置
            app.manage(AppPreferences::new(std::collections::HashMap::new()));

            // 8. 创建系统托盘（仅桌面平台）
            #[cfg(desktop)]
            {
                create_system_tray(app_handle)?;
                setup_window_close_handler(app_handle)?;
                tauri::async_runtime::spawn(setup(cloned_handle));
            }

            #[cfg(any(target_os = "android", target_os = "ios"))]
            {
                let cloned_handle = app_handle.clone();
                tauri::async_runtime::spawn(setup(cloned_handle));
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

// An async function that does some heavy setup task
async fn setup(app: AppHandle) -> Result<(), ()> {
    // 在移动端减少初始化延迟
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        eprintln!("Performing mobile backend setup task...");
        sleep(Duration::from_millis(500)).await; // 移动端减少到500ms
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        eprintln!("Performing really heavy backend setup task...");
        sleep(Duration::from_secs(3)).await; // 桌面端保持3秒
    }

    // 创建默认用户
    let app_state = app.state::<AppState>();
    if let Err(e) = create_default_user(&app_state.db).await {
        eprintln!("Failed to create default user: {}", e);
        // 不返回错误，让应用继续启动
    }

    // 启动定时任务处理未来交易
    let app_clone = app.clone();
    tauri::async_runtime::spawn(async move {
        start_transaction_scheduler(app_clone).await;
    });

    eprintln!("Backend setup task completed!");
    // Set the backend task as being completed
    // Commands can be ran as regular functions as long as you take
    // care of the input arguments yourself
    set_complete(app.clone(), app.state::<AppState>(), "backend".to_string()).await?;
    Ok(())
}

#[cfg(desktop)]
fn create_system_tray(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    // 创建菜单项
    let settings_item = MenuItem::with_id(app, "settings", "设置", true, None::<&str>)?;
    let quit_item = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;

    // 创建菜单 - 使用官方文档推荐的方式
    let menu = MenuBuilder::new(app)
        .item(&settings_item)
        .separator()
        .item(&quit_item)
        .build()?;

    // 创建托盘图标 - 使用官方文档推荐的方式
    let _tray = TrayIconBuilder::new()
        .icon(app.default_window_icon().unwrap().clone())
        .menu(&menu)
        .show_menu_on_left_click(false) // 防止左键点击时显示菜单
        .on_menu_event(|app, event| {
            match event.id.as_ref() {
                "settings" => {
                    // 导航到设置页面
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.show();
                        let _ = window.set_focus();
                        let _ = window.eval("window.location.hash = '#/settings'");
                    }
                }
                "quit" => {
                    app.exit(0);
                }
                _ => {}
            }
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                // 左键点击托盘图标显示/隐藏窗口
                let app = tray.app_handle();
                if let Some(window) = app.get_webview_window("main") {
                    if window.is_visible().unwrap_or(false) {
                        let _ = window.hide();
                    } else {
                        let _ = window.unminimize();
                        let _ = window.show();
                        let _ = window.set_focus();
                    }
                }
            }
        })
        .build(app)?;

    Ok(())
}

#[cfg(desktop)]
fn setup_window_close_handler(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    if let Some(window) = app.get_webview_window("main") {
        let app_handle = app.clone();
        window.on_window_event(move |event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                println!("CloseRequested event received");
                // 阻止默认关闭行为
                api.prevent_close();

                // 检查当前页面是否为登录或注册页面
                let app_handle_clone = app_handle.clone();
                tauri::async_runtime::spawn(async move {
                    if let Some(window) = app_handle_clone.get_webview_window("main") {
                        // 发送检查事件到前端
                        let result = window.emit("check-auth-page", ());
                        match result {
                            Ok(_) => println!("Check auth page event emitted successfully"),
                            Err(e) => println!("Failed to emit check auth page event: {}", e),
                        }
                    } else {
                        println!("No main window found");
                    }
                });
            }
        });
    } else {
        eprintln!("No main window found during setup");
    }
    Ok(())
}

/// 启动交易定时任务
async fn start_transaction_scheduler(app: AppHandle) {
    let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(60 * 60 * 2)); // 每2小时检查一次

    loop {
        interval.tick().await;

        // 处理到期的未来交易
        let app_state = app.state::<AppState>();
        let db = app_state.db.clone();
        let installment_service = money::services::installment::get_installment_service();

        match installment_service.auto_process_due_installments(&db).await {
            Ok(processed_transactions) => {
                if !processed_transactions.is_empty() {
                    log::info!("处理了 {} 笔到期交易", processed_transactions.len());

                    // 通知前端刷新数据
                    if let Err(e) = app.emit(
                        "installment-processed",
                        InstallmentProcessedEvent {
                            processed_count: processed_transactions.len(),
                            timestamp: chrono::Local::now().timestamp(),
                        },
                    ) {
                        log::error!("发送分期处理完成事件失败: {}", e);
                    }
                }
            }
            Err(e) => {
                log::error!("处理到期交易失败: {}", e);

                // 通知前端处理失败
                if let Err(emit_err) = app.emit(
                    "installment-process-failed",
                    InstallmentProcessFailedEvent {
                        error: e.to_string(),
                        timestamp: chrono::Utc::now().timestamp(),
                    },
                ) {
                    log::error!("发送分期处理失败事件失败: {}", emit_err);
                }
            }
        }
    }
}
