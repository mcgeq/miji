// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           init.rs
// Description:    About mobile init plugins
// Create   Date:  2025-06-22 17:38:35
// Last Modified:  2025-06-28 10:42:44
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use tauri::Runtime;
pub trait MijiInit {
    fn init_plugin(self) -> Self;
}

impl<R: Runtime> MijiInit for tauri::Builder<R> {
    fn init_plugin(self) -> Self {
        self.plugin(tauri_plugin_vue::init())
    }
}
