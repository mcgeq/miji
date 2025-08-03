// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000002_create_project.rs
// Description:    About Project Migration
// Create   Date:  2025-06-10 23:34:28
// Last Modified:  2025-06-14 22:42:54
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use crate::schema::MijiMigrationTrait;
use tauri_plugin_sql::Migration;

pub struct ProjectMigration;
pub struct TodoProjectMigration;

impl MijiMigrationTrait for ProjectMigration {
    fn up() -> Migration {
        Migration {
            version: 2,
            description: "create Project table and index",
            sql: r#"
                CREATE TABLE IF NOT EXISTS project (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    name TEXT NOT NULL,
                    description TEXT CHECK (LENGTH(description) <= 1000),
                    owner_id TEXT CHECK (LENGTH(owner_id) <= 38),
                    color TEXT,
                    is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
                    created_at TEXT NOT NULL,
                    updated_at TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_project_name ON project (name);
                CREATE INDEX IF NOT EXISTS idx_project_owner ON project (owner_id);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 2,
            description: "drop Project table and index",
            sql: r#"
                DROP INDEX IF EXISTS idx_project_name;
                DROP INDEX IF EXISTS idx_project_owner;
                DROP TABLE IF EXISTS project;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for TodoProjectMigration {
    fn up() -> Migration {
        Migration {
            version: 3,
            description: "create TodoProject table and indexes",
            sql: r#"
                CREATE TABLE IF NOT EXISTS todo_project (
                    todo_serial_num TEXT NOT NULL CHECK(LENGTH(todo_serial_num) <= 38),
                    project_serial_num TEXT NOT NULL CHECK(LENGTH(project_serial_num) <= 38),
                    order_index INTEGER,
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    PRIMARY KEY (todo_serial_num, project_serial_num),
                    FOREIGN KEY (todo_serial_num)
                        REFERENCES todo(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE,
                    FOREIGN KEY (project_serial_num)
                        REFERENCES project(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_todoproject_todo
                    ON todo_project (todo_serial_num);
                CREATE INDEX IF NOT EXISTS idx_todoproject_project
                    ON todo_project (project_serial_num);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 3,
            description: "drop TodoProject table and indexes",
            sql: r#"
                DROP INDEX IF EXISTS idx_todoproject_todo;
                DROP INDEX IF EXISTS idx_todoproject_project;
                DROP TABLE IF EXISTS todo_project;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
