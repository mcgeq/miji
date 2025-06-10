// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000001_create_user.rs
// Description:    About User Migration
// Create   Date:  2025-06-10 23:33:06
// Last Modified:  2025-06-10 23:33:15
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
use tauri_plugin_sql::Migration;

use crate::schema::MijiMigrationTrait;

pub struct UserMigration;

impl MijiMigrationTrait for UserMigration {
    fn up() -> Migration {
        Migration {
            version: 1,
            description: "create User table and indexes",
            sql: r#"
                CREATE TABLE IF NOT EXISTS user (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    name TEXT NOT NULL UNIQUE,
                    email TEXT NOT NULL UNIQUE,
                    phone TEXT UNIQUE,
                    password_hash TEXT NOT NULL,
                    avatar_url TEXT,
                    last_login_at DATETIME,
                    is_verified BOOLEAN NOT NULL DEFAULT 0,
                    role INTEGER NOT NULL DEFAULT 1,
                    status INTEGER NOT NULL DEFAULT 0,
                    email_verified_at DATETIME,
                    phone_verified_at DATETIME,
                    bio TEXT,
                    language TEXT,
                    timezone TEXT,
                    last_active_at DATETIME,
                    deleted_at DATETIME,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME
                );
                CREATE INDEX IF NOT EXISTS idx_user_email ON user (email);
                CREATE INDEX IF NOT EXISTS idx_user_status ON user (status);
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
                DROP INDEX IF EXISTS idx_user_email;
                DROP TABLE IF EXISTS user;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
