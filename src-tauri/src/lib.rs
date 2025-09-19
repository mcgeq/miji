use migration::{Migrator, MigratorTrait};
use tauri::Manager;

pub mod logging;

#[cfg(desktop)]
mod desktops;

mod commands;
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
    ApiCredentials, AppState, business_code::BusinessCode, config::Config, error::AppError,
};
use dotenvy::dotenv;
use plugins::generic_plugins;
use std::sync::Arc;
use tokio::sync::Mutex;

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
            };

            // 6. 管理应用状态
            app.manage(app_state.clone());

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
