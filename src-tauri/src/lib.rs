// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
use tauri::Manager;
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {name}! You've been greeted from Rust!")
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = {
        let builder = tauri::Builder::default()
            .plugin(tauri_plugin_os::init())
            .plugin(tauri_plugin_notification::init())
            .plugin(tauri_plugin_fs::init())
            .plugin(tauri_plugin_store::Builder::new().build())
            .plugin(tauri_plugin_opener::init())
            .invoke_handler(tauri::generate_handler![greet]);

        // ✅ 在非 Android 平台时注册单实例插件
        #[cfg(not(target_os = "android"))]
        let builder = builder.plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            let _ = app
                .get_webview_window("main")
                .expect("no main window")
                .set_focus();
        }));

        builder
    };

    builder
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
