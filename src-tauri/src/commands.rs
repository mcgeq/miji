use common::AppState;
use log::info;
use tauri::{Builder, State, Wry};

#[tauri::command]
async fn greet(name: String, state: State<'_, AppState>) -> Result<String, String> {
    let _db = state.db.clone();
    info!("Greet {name}");
    Ok(format!("Hello, {name}! You've been greeted from Rust!"))
}

pub fn init_commands(builder: Builder<Wry>) -> Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![greet,])
}
