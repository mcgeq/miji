use log::{error, info};
use tauri::Manager;
use tauri_plugin_log::{Target, fern::colors::ColoredLevelConfig};
#[tauri::command]
fn greet(name: &str) -> String {
    info!("Greet {}", name);
    format!("Hello, {name}! You've been greeted from Rust!")
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = {
        let builder = tauri::Builder::default()
            .plugin(
                tauri_plugin_log::Builder::default()
                    .targets([
                        Target::new(tauri_plugin_log::TargetKind::Stdout),
                        Target::new(tauri_plugin_log::TargetKind::Webview),
                        Target::new(tauri_plugin_log::TargetKind::LogDir {
                            file_name: Some("logs".to_string()),
                        }),
                    ])
                    .with_colors(ColoredLevelConfig::default())
                    .build(),
            )
            .plugin(tauri_plugin_os::init())
            .plugin(tauri_plugin_notification::init())
            .plugin(tauri_plugin_fs::init())
            .plugin(tauri_plugin_store::Builder::new().build())
            .plugin(tauri_plugin_opener::init());

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
        .invoke_handler(tauri::generate_handler![greet])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
    error!("Error");
}
