// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m_000001_todos.rs
// Description:    About Todos Sqlite Migrations
// Create   Date:  2025-06-10 19:59:22
// Last Modified:  2025-06-10 22:21:35
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use tauri_plugin_sql::Migration;

pub trait MijiMigrationTrait {
    fn up() -> Migration;
    fn down() -> Migration;
}

pub struct TodoMigration;

impl MijiMigrationTrait for TodoMigration {
    fn up() -> Migration {
        Migration {
            version: 1,
            description: "create Todo table",
            sql: "",
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }
    fn down() -> Migration {
        Migration {
            version: 1,
            description: "Delete todo table",
            sql: "",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
