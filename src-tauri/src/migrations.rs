// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           migrations.rs
// Description:    About Sqlite Migrations
// Create   Date:  2025-06-10 19:40:47
// Last Modified:  2025-06-10 20:10:47
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use migration::m_000001_todos::{MijiMigrationTrait, TodoMigration};
use tauri::Runtime;

pub trait MijiMigrations {
    fn init_migrations(self) -> Self;
}

impl<R: Runtime> MijiMigrations for tauri::Builder<R> {
    fn init_migrations(self) -> Self {
        let mig = vec![TodoMigration::up()];
        self.plugin(
            tauri_plugin_sql::Builder::default()
                .add_migrations("miji.db", mig)
                .build(),
        )
    }
}
