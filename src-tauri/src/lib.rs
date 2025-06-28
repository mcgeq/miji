#[cfg(desktop)]
mod desktops;

mod commands;
mod migrations;
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
use common::{ApiCredentials, AppState};
use migrations::MijiMigrations;
use plugins::generic_plugins;
use std::sync::Arc;
use tokio::sync::Mutex;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let api_credentials = ApiCredentials::load_from_env().unwrap();
    let app_state = AppState {
        db: Arc::new("null".to_string()),
        credentials: Arc::new(Mutex::new(api_credentials)),
    };
    let builder = tauri::Builder::default();
    let builder = generic_plugins(builder);
    #[cfg(desktop)]
    let builder = builder.init_plugin();

    #[cfg(any(target_os = "android", target_os = "ios"))]
    let builder = builder.init_plugin();

    let builder = builder.init_migrations();

    let builder = init_commands(builder);
    builder
        .manage(app_state.clone())
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
