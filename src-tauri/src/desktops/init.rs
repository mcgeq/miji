// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           init.rs
// Description:    About Desktop Initialize
// Create   Date:  2025-06-10 14:57:48
// Last Modified:  2025-06-28 10:41:33
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::utils::files::MijiFiles;
use log::LevelFilter;
use tauri::{Manager, Runtime};
use tauri_plugin_log::{Target, fern::colors::ColoredLevelConfig};

pub trait MijiInit {
    fn init_plugin(self) -> Self;
}

impl<R: Runtime> MijiInit for tauri::Builder<R> {
    fn init_plugin(self) -> Self {
        let root_dir = MijiFiles::root_path().unwrap();
        eprintln!("root_dir: {root_dir}");

        self.plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--flag1", "--flag2"]),
        ))
        .plugin(tauri_plugin_vue::Builder::new().path(&root_dir).build())
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
    }
}
