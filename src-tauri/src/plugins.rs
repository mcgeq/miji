// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           plugins.rs
// Description:    About init plugins
// Create   Date:  2025-05-24 19:32:49
// Last Modified:  2025-06-08 22:48:55
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::utils::files::MijiFiles;
use log::LevelFilter;
use tauri::{Builder, Manager, Wry};
use tauri_plugin_log::{Target, fern::colors::ColoredLevelConfig};

pub fn init_plugins(builder: Builder<Wry>) -> Builder<Wry> {
    let root_dir = MijiFiles::root_path().unwrap();
    eprintln!("root_dir: {root_dir}");
    let builder = builder
        .plugin(
            tauri_plugin_log::Builder::default()
                .max_file_size(10 * 1024)
                .rotation_strategy(tauri_plugin_log::RotationStrategy::KeepAll)
                .targets([
                    Target::new(tauri_plugin_log::TargetKind::Stdout),
                    Target::new(tauri_plugin_log::TargetKind::Webview),
                    Target::new(tauri_plugin_log::TargetKind::Folder {
                        path: MijiFiles::join(&[&root_dir, "logs"]),
                        file_name: Some("miji".to_string()),
                    }),
                ])
                .timezone_strategy(tauri_plugin_log::TimezoneStrategy::UseLocal)
                .level(LevelFilter::Debug)
                .filter(|metadata| {
                    !(metadata.target() == "sea_orm::driver::sqlx_sqlite"
                        && metadata.level() == log::Level::Debug)
                })
                .with_colors(ColoredLevelConfig::default())
                .build(),
        )
        .plugin(tauri_plugin_sql::Builder::new().build())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_dialog::init())
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
}
