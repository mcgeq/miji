// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           plugins.rs
// Description:    About init plugins
// Create   Date:  2025-05-24 19:32:49
// Last Modified:  2025-06-22 17:36:47
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::utils::files::MijiFiles;
use tauri::{Builder, Wry};

pub fn generic_plugins(builder: Builder<Wry>) -> Builder<Wry> {
    // 获取应用根目录
    let root_dir = MijiFiles::root_path().unwrap_or_else(|_| ".".into());

    // 配置 pinia store 路径
    let pinia_store_path = format!("{}/stores", root_dir);

    builder
        .plugin(tauri_plugin_sql::Builder::new().build())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(
            tauri_plugin_pinia::Builder::new()
                .path(&pinia_store_path)
                .build(),
        )
}
