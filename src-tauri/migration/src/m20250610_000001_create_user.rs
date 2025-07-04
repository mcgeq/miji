// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000001_create_user.rs
// Description:    About User Migration
// Create   Date:  2025-06-10 23:33:06
// Last Modified:  2025-06-15 13:30:45
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use crate::schema::MijiMigrationTrait;
use tauri_plugin_sql::Migration;

pub struct UserMigration;

impl MijiMigrationTrait for UserMigration {
    fn up() -> Migration {
        Migration {
            version: 1,
            description: "create User table and indexes",
            sql: r#"
                CREATE TABLE IF NOT EXISTS users (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    name TEXT NOT NULL UNIQUE,
                    email TEXT NOT NULL UNIQUE,
                    phone TEXT UNIQUE,
                    password TEXT NOT NULL,
                    avatar_url TEXT,
                    last_login_at TEXT,
                    is_verified INTEGER NOT NULL DEFAULT 0 CHECK (is_verified IN (0, 1)),
                    role TEXT NOT NULL DEFAULT 'User' CHECK (role IN ('Admin', 'User', 'Moderator', 'Editor', 'Guest', 'Developer', 'Owner')),
                    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Active', 'Inactive', 'Suspended', 'Banned', 'Pending', 'Deleted')),
                    email_verified_at TEXT,
                    phone_verified_at TEXT,
                    bio TEXT,
                    language TEXT,
                    timezone TEXT,
                    last_active_at TEXT,
                    deleted_at TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_user_status ON users (status);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 1,
            description: "drop User table and indexes",
            sql: r#"
                DROP INDEX IF EXISTS idx_user_status;
                DROP TABLE IF EXISTS users;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
