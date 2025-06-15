// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           plugins.rs
// Description:    About init plugins
// Create   Date:  2025-05-24 19:32:49
// Last Modified:  2025-06-15 09:07:07
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::utils::files::MijiFiles;
use tauri::{Builder, Wry};

pub fn generic_plugins(builder: Builder<Wry>) -> Builder<Wry> {
    let root_dir = MijiFiles::root_path().unwrap();
    builder
        .plugin(tauri_plugin_sql::Builder::new().build())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_svelte::Builder::new().path(root_dir).build())
        .plugin(tauri_plugin_opener::init())
}
