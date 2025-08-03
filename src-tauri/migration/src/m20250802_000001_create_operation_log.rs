// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000004_create_tags.rs
// Description:    About log Migration
// Create   Date:  2025-06-10 23:34:05
// Last Modified:  2025-06-14 22:43:10
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
use tauri_plugin_sql::Migration;

use crate::schema::MijiMigrationTrait;

pub struct OperationLogMigration;

impl MijiMigrationTrait for OperationLogMigration {
    fn up() -> Migration {
        Migration {
            version: 25,
            description: "create Operation log table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS operation_log (
                    serial_num TEXT PRIMARY KEY NOT NULL CHECK(LENGTH(serial_num) = 38),
                    recorded_at TEXT NOT NULL,
                    operation TEXT NOT NULL CHECK(operation IN ('INSERT', 'UPDATE', 'DELETE', 'SOFT_DELETE', 'RESTORE')),
                    target_table TEXT NOT NULL,
                    record_id TEXT NOT NULL,
                    actor_id TEXT NOT NULL CHECK(LENGTH(actor_id) > 0),
                    changes_json TEXT,
                    snapshot_json TEXT,
                    device_id TEXT CHECK(LENGTH(device_id) <= 100)
                );
                CREATE INDEX idx_oplog_main ON operation_log(target_table, recorded_at, operation);
                CREATE INDEX idx_oplog_target ON operation_log(target_table, record_id);
                CREATE INDEX idx_oplog_actor ON operation_log(actor_id, recorded_at);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 25,
            description: "drop Tag table",
            sql: "DROP TABLE IF EXISTS tag;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
