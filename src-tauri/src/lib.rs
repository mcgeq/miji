mod commands;
mod plugins;

use std::sync::Arc;

use commands::init_commands;
use common::{AppState, db::get_db_conn};
use plugins::init_plugins;
use tokio::runtime::Runtime;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let rt = Runtime::new().expect("Failed to create Tokio runtime");
    let db_conn = rt.block_on(async { get_db_conn().await.expect("Database connection failed") });
    let app_state = AppState {
        db: Arc::new(db_conn),
    };

    let builder = tauri::Builder::default().manage(app_state.clone());
    let builder = init_plugins(builder);
    let builder = init_commands(builder);
    builder
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
