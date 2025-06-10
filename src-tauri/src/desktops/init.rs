// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           init.rs
// Description:    About Desktop Initialize
// Create   Date:  2025-06-10 14:57:48
// Last Modified:  2025-06-10 18:44:49
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::utils::files::MijiFiles;
use log::LevelFilter;
use std::sync::Arc;
use tauri::{Manager, Runtime};
use tauri_plugin_log::{Target, fern::colors::ColoredLevelConfig};

use common::{ApiCredentials, AppState, db::get_db_conn};
use tokio::{runtime::Runtime as TokioRuntime, sync::Mutex};

pub trait MijiInit {
    fn init_plugin(self) -> Self;
}

impl<R: Runtime> MijiInit for tauri::Builder<R> {
    fn init_plugin(self) -> Self {
        let root_dir = MijiFiles::root_path().unwrap();
        eprintln!("root_dir: {root_dir}");
        let rt = TokioRuntime::new().expect("Failed to create Tokio runtime");
        let db_conn =
            rt.block_on(async { get_db_conn().await.expect("Database connection failed") });
        let api_credentials = ApiCredentials::load_from_env().unwrap();
        let app_state = AppState {
            db: Arc::new(db_conn),
            credentials: Arc::new(Mutex::new(api_credentials)),
        };

        self.plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--flag1", "--flag2"]),
        ))
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            let _ = app
                .get_webview_window("main")
                .expect("no main window")
                .set_focus();
        }))
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
        .manage(app_state)
    }
}
