use migration::{Migrator, MigratorTrait};
use tauri::{AppHandle, Manager, Emitter, menu::{MenuBuilder, MenuItem}, tray::{TrayIconBuilder, TrayIconEvent, MouseButton, MouseButtonState}, WindowEvent};

pub mod logging;

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

use crate::commands::set_complete;
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

            // 7. 创建系统托盘（仅桌面平台）
            #[cfg(desktop)]
            {
                create_system_tray(&app_handle)?;
                setup_window_close_handler(&app_handle)?;
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
            match event {
                TrayIconEvent::Click {
                    button: MouseButton::Left,
                    button_state: MouseButtonState::Up,
                    ..
                } => {
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
                _ => {}
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
            match event {
                WindowEvent::CloseRequested { api, .. } => {
                    // 阻止默认关闭行为
                    api.prevent_close();
                    
                    // 发送事件到前端显示对话框
                    if let Some(window) = app_handle.get_webview_window("main") {
                        let _ = window.emit("show-close-dialog", ());
                    }
                }
                _ => {}
            }
        });
    }
    Ok(())
}
