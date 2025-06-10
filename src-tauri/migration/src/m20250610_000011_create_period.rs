// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000011_create_period.rs
// Description:    About Period Migration
// Create   Date:  2025-06-10 23:33:49
// Last Modified:  2025-06-10 23:33:58
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
use tauri_plugin_sql::Migration;

use crate::schema::MijiMigrationTrait;

pub struct PeriodRecordsMigration;
pub struct PeriodSymptomsMigration;
pub struct PeriodPmsRecordsMigration;
pub struct PeriodPmsSymptomsMigration;

impl MijiMigrationTrait for PeriodRecordsMigration {
    fn up() -> Migration {
        Migration {
            version: 10,
            description: "create PeriodRecords table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS period_records (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    start_date DATE NOT NULL,
                    end_date DATE NOT NULL,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 10,
            description: "drop PeriodRecords table",
            sql: "DROP TABLE IF EXISTS period_records;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

pub struct PeriodDailyRecordsMigration;

impl MijiMigrationTrait for PeriodDailyRecordsMigration {
    fn up() -> Migration {
        Migration {
            version: 11,
            description: "create PeriodDailyRecords table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS period_daily_records (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    period_serial_num TEXT NOT NULL,
                    date DATE NOT NULL,
                    flow_level INTEGER,
                    sexual_activity BOOLEAN NOT NULL,
                    exercise_intensity INTEGER NOT NULL DEFAULT 0,
                    diet TEXT NOT NULL,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (period_serial_num)
                        REFERENCES period_records(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 11,
            description: "drop PeriodDailyRecords table",
            sql: "DROP TABLE IF EXISTS period_daily_records;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for PeriodSymptomsMigration {
    fn up() -> Migration {
        Migration {
            version: 12,
            description: "create PeriodSymptoms table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS period_symptoms (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    period_daily_records_serial_num TEXT NOT NULL,
                    symptom_type INTEGER NOT NULL,
                    intensity INTEGER NOT NULL,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (period_daily_records_serial_num)
                        REFERENCES period_daily_records(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 12,
            description: "drop PeriodSymptoms table",
            sql: "DROP TABLE IF EXISTS period_symptoms;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for PeriodPmsRecordsMigration {
    fn up() -> Migration {
        Migration {
            version: 13,
            description: "create PeriodPmsRecords table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS period_pms_records (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    period_serial_num TEXT NOT NULL,
                    start_date DATE NOT NULL,
                    end_date DATE NOT NULL,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (period_serial_num)
                        REFERENCES period_records(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 13,
            description: "drop PeriodPmsRecords table",
            sql: "DROP TABLE IF EXISTS period_pms_records;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for PeriodPmsSymptomsMigration {
    fn up() -> Migration {
        Migration {
            version: 14,
            description: "create PeriodPmsSymptoms table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS period_pms_symptoms (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    period_pms_records_serial_num TEXT NOT NULL,
                    symptom_type INTEGER NOT NULL DEFAULT 0,
                    intensity INTEGER NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (period_pms_records_serial_num)
                        REFERENCES period_pms_records(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 14,
            description: "drop PeriodPmsSymptoms table",
            sql: "DROP TABLE IF EXISTS period_pms_symptoms;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
