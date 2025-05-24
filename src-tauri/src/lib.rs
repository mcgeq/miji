mod commands;
mod plugins;

use commands::init_commands;
use plugins::init_plugins;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default();
    let builder = init_plugins(builder);
    let builder = init_commands(builder);
    builder
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
