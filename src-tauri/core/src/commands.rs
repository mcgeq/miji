// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About commands trait
// Create   Date:  2025-05-24 19:53:20
// Last Modified:  2025-05-24 20:32:28
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use tauri::{Builder, Wry};

pub trait MijiCommands {
    fn register(builder: Builder<Wry>) -> Builder<Wry>;
}
