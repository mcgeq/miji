// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m_000001_todos.rs
// Description:    About Todos Sqlite Migrations
// Create   Date:  2025-06-10 19:59:22
// Last Modified:  2025-06-10 23:32:40
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use tauri_plugin_sql::Migration;

use crate::schema::MijiMigrationTrait;

pub struct TodoMigration;
pub struct TodoTagMigration;
pub struct TaskDependencyMigration;
pub struct AttachmentMigration;
pub struct ReminderMigration;

impl MijiMigrationTrait for TodoMigration {
    fn up() -> Migration {
        Migration {
            version: 4,
            description: "create Todo table and indexes",
            sql: r#"
                CREATE TABLE IF NOT EXISTS todo (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    due_at DATETIME NOT NULL,
                    priority INTEGER NOT NULL DEFAULT 0,
                    status INTEGER NOT NULL DEFAULT 0,
                    repeat TEXT,
                    completed_at DATETIME,
                    assignee_id TEXT,
                    progress INTEGER NOT NULL DEFAULT 0,
                    location TEXT,
                    owner_id TEXT,
                    is_archived BOOLEAN NOT NULL DEFAULT 0,
                    is_pinned BOOLEAN NOT NULL DEFAULT 0,
                    estimate_minutes INTEGER,
                    reminder_count INTEGER NOT NULL DEFAULT 0,
                    parent_id TEXT,
                    subtask_order INTEGER,
                    FOREIGN KEY (owner_id)
                        REFERENCES user(serial_num)
                        ON DELETE SET NULL
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_todo_due_date ON todo (due_at);
                CREATE INDEX IF NOT EXISTS idx_todo_status ON todo (status);
                CREATE INDEX IF NOT EXISTS idx_todo_priority ON todo (priority);
                CREATE INDEX IF NOT EXISTS idx_todo_created_at ON todo (created_at);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 4,
            description: "drop Todo table and indexes",
            sql: r#"
                DROP INDEX IF EXISTS idx_todo_created_at;
                DROP INDEX IF EXISTS idx_todo_priority;
                DROP INDEX IF EXISTS idx_todo_status;
                DROP INDEX IF EXISTS idx_todo_due_date;
                DROP TABLE IF EXISTS todo;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for TodoTagMigration {
    fn up() -> Migration {
        Migration {
            version: 1,
            description: "create TodoTag table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS todo_tag (
                    todo_serial_num TEXT NOT NULL,
                    tag_serial_num TEXT NOT NULL,
                    order INTEGER,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    PRIMARY KEY (todo_serial_num, tag_serial_num),
                    FOREIGN KEY (todo_serial_num)
                        REFERENCES todo(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE,
                    FOREIGN KEY (tag_serial_num)
                        REFERENCES tag(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 1,
            description: "drop TodoTag table",
            sql: "DROP TABLE IF EXISTS todo_tag;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for TaskDependencyMigration {
    fn up() -> Migration {
        Migration {
            version: 2,
            description: "create TaskDependency table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS task_dependency (
                    task_serial_num TEXT NOT NULL,
                    depends_on_task_serial_num TEXT NOT NULL,
                    PRIMARY KEY (task_serial_num, depends_on_task_serial_num),
                    FOREIGN KEY (task_serial_num)
                        REFERENCES todo(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE,
                    FOREIGN KEY (depends_on_task_serial_num)
                        REFERENCES todo(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 2,
            description: "drop TaskDependency table",
            sql: "DROP TABLE IF EXISTS task_dependency;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for AttachmentMigration {
    fn up() -> Migration {
        Migration {
            version: 3,
            description: "create Attachment table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS attachment (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    todo_serial_num TEXT NOT NULL,
                    file_path TEXT,
                    url TEXT,
                    file_name TEXT,
                    mime_type TEXT,
                    size INTEGER,
                    created_at DATETIME NOT NULL,
                    FOREIGN KEY (todo_serial_num)
                        REFERENCES todo(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 3,
            description: "drop Attachment table",
            sql: "DROP TABLE IF EXISTS attachment;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for ReminderMigration {
    fn up() -> Migration {
        Migration {
            version: 4,
            description: "create Reminder table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS reminder (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    todo_serial_num TEXT NOT NULL,
                    remind_at DATETIME NOT NULL,
                    type INTEGER,
                    is_sent BOOLEAN NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (todo_serial_num)
                        REFERENCES todo(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 4,
            description: "drop Reminder table",
            sql: "DROP TABLE IF EXISTS reminder;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
