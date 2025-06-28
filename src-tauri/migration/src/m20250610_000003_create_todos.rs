// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m_000001_todos.rs
// Description:    About Todos Sqlite Migrations
// Create   Date:  2025-06-10 19:59:22
// Last Modified:  2025-06-25 22:24:47
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use crate::schema::MijiMigrationTrait;
use tauri_plugin_sql::Migration;

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
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    title TEXT NOT NULL,
                    description TEXT CHECK (LENGTH(description) <= 1000),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    due_at TEXT NOT NULL,
                    priority TEXT NOT NULL DEFAULT 'Low' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
                    status TEXT NOT NULL DEFAULT 'NotStarted' CHECK (status IN ('NotStarted', 'InProgress', 'Completed', 'Cancelled', 'Overdue')),
                    repeat TEXT,
                    completed_at TEXT,
                    assignee_id TEXT CHECK (LENGTH(assignee_id) <= 38),
                    progress INTEGER NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
                    location TEXT,
                    owner_id TEXT CHECK (LENGTH(owner_id) <= 38),
                    is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0,1)),
                    is_pinned INTEGER NOT NULL DEFAULT 0 CHECK (is_pinned IN (0,1)),
                    estimate_minutes INTEGER,
                    reminder_count INTEGER NOT NULL DEFAULT 0,
                    parent_id TEXT CHECK (LENGTH(parent_id) <= 38),
                    subtask_order INTEGER,
                    FOREIGN KEY (owner_id)
                        REFERENCES users(serial_num)
                        ON DELETE SET NULL
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_todo_due_date ON todo (due_at);
                CREATE INDEX IF NOT EXISTS idx_todo_status ON todo (status);
                CREATE INDEX IF NOT EXISTS idx_todo_priority ON todo (priority);
                CREATE INDEX IF NOT EXISTS idx_todo_created_at ON todo (created_at);
                CREATE INDEX IF NOT EXISTS idx_todo_owner_id ON todo (owner_id);
                CREATE INDEX IF NOT EXISTS idx_todo_parent_id ON todo (parent_id);
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
                DROP INDEX IF EXISTS idx_todo_owner_id;
                DROP INDEX IF EXISTS idx_todo_parent_id;
                DROP TABLE IF EXISTS todo;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for TodoTagMigration {
    fn up() -> Migration {
        Migration {
            version: 5,
            description: "create TodoTag table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS todo_tag (
                    todo_serial_num TEXT NOT NULL CHECK (LENGTH(todo_serial_num) <= 38),
                    tag_serial_num TEXT NOT NULL CHECK (LENGTH(tag_serial_num) <= 38),
                    orders INTEGER,
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
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
                CREATE INDEX IF NOT EXISTS idx_todo_tag_todo ON todo_tag(todo_serial_num);
                CREATE INDEX IF NOT EXISTS idx_todo_tag_tag ON todo_tag(tag_serial_num);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 5,
            description: "drop TodoTag table",
            sql: "DROP TABLE IF EXISTS todo_tag;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for TaskDependencyMigration {
    fn up() -> Migration {
        Migration {
            version: 6,
            description: "create TaskDependency table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS task_dependency (
                    task_serial_num TEXT NOT NULL CHECK (LENGTH(task_serial_num) <= 38),
                    depends_on_task_serial_num TEXT NOT NULL CHECK (LENGTH(depends_on_task_serial_num) <= 38),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
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
                CREATE INDEX IF NOT EXISTS idx_task_dependency_task ON task_dependency(task_serial_num);
                CREATE INDEX IF NOT EXISTS idx_task_dependency_depends ON task_dependency(depends_on_task_serial_num);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 6,
            description: "drop TaskDependency table",
            sql: "DROP TABLE IF EXISTS task_dependency;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for AttachmentMigration {
    fn up() -> Migration {
        Migration {
            version: 7,
            description: "create Attachment table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS attachment (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    todo_serial_num TEXT NOT NULL CHECK (LENGTH(todo_serial_num) <= 38),
                    file_path TEXT,
                    url TEXT,
                    file_name TEXT,
                    mime_type TEXT,
                    size INTEGER,
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (todo_serial_num)
                        REFERENCES todo(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_attachment_todo ON attachment(todo_serial_num);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 7,
            description: "drop Attachment table",
            sql: "DROP TABLE IF EXISTS attachment;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for ReminderMigration {
    fn up() -> Migration {
        Migration {
            version: 8,
            description: "create Reminder table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS reminder (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    todo_serial_num TEXT NOT NULL CHECK (LENGTH(todo_serial_num) <= 38),
                    remind_at DATETIME NOT NULL,
                    type INTEGER,
                    is_sent INTEGER NOT NULL DEFAULT 0 CHECK (is_sent IN (0,1)),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (todo_serial_num)
                        REFERENCES todo(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_reminder_todo ON reminder(todo_serial_num);
                CREATE INDEX IF NOT EXISTS idx_reminder_remind_at ON reminder(remind_at);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 8,
            description: "drop Reminder table",
            sql: "DROP TABLE IF EXISTS reminder;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
