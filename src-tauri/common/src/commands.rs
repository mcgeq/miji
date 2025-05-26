// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Command Trait
// Create   Date:  2025-05-26 10:31:14
// Last Modified:  2025-05-26 10:33:46
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use tauri::{Builder, Wry};

pub trait MijiCommands {
    fn register(builder: Builder<Wry>) -> Builder<Wry>;
}
