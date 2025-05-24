use log::info;
use tauri::{Builder, Wry};

#[tauri::command]
fn greet(name: &str) -> String {
    info!("Greet {name}");
    format!("Hello, {name}! You've been greeted from Rust!")
}

pub fn init_commands(builder: Builder<Wry>) -> Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![greet])
}
