// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           init.rs
// Description:    移动端初始化
// Create   Date:  2025-11-12 16:08:08
// -----------------------------------------------------------------------------

pub mod notification_setup;
pub mod system_monitor;

use tauri::{App, AppHandle, Manager};

pub trait MijiInit {
    fn init_plugin(self) -> Self;
}

impl<R: Runtime> MijiInit for tauri::Builder<R> {
    fn init_plugin(self) -> Self {
        self.plugin(tauri_plugin_log::Builder::new().build())
            .plugin(tauri_plugin_pinia::init())
    }
}
