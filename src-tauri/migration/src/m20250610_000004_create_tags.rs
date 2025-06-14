// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000004_create_tags.rs
// Description:    About Tag Migration
// Create   Date:  2025-06-10 23:34:05
// Last Modified:  2025-06-14 22:43:10
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
use tauri_plugin_sql::Migration;

use crate::schema::MijiMigrationTrait;

pub struct TagMigration;

impl MijiMigrationTrait for TagMigration {
    fn up() -> Migration {
        Migration {
            version: 9,
            description: "create Tag table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS tag (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    name TEXT NOT NULL UNIQUE,
                    description TEXT CHECK (LENGTH(description) <= 1000),
                    created_at TEXT NOT NULL,
                    updated_at TEXT
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 9,
            description: "drop Tag table",
            sql: "DROP TABLE IF EXISTS tag;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
