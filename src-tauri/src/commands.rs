use common::{AppState, db::get_database_version};
use log::{error, info};
use tauri::{Builder, State, Wry};

#[tauri::command]
async fn greet(name: String, state: State<'_, AppState>) -> Result<String, String> {
    let db = state.db.clone();
    match get_database_version(&db).await {
        Ok(version) => {
            info!("Database Version: {version}");
        }
        Err(e) => error!("Failed to get database version: {e}"),
    }
    info!("Greet {name}");
    Ok(format!("Hello, {name}! You've been greeted from Rust!"))
}

pub fn init_commands(builder: Builder<Wry>) -> Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![greet, auth::commands::register])
}
