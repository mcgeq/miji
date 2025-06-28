// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000011_create_period.rs
// Description:    About Period Migration
// Create   Date:  2025-06-10 23:33:49
// Last Modified:  2025-06-14 22:37:59
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use crate::schema::MijiMigrationTrait;
use tauri_plugin_sql::Migration;

pub struct PeriodRecordsMigration;
pub struct PeriodDailyRecordsMigration;
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
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    start_date TEXT NOT NULL,
                    end_date TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT
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

impl MijiMigrationTrait for PeriodDailyRecordsMigration {
    fn up() -> Migration {
        Migration {
            version: 11,
            description: "create PeriodDailyRecords table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS period_daily_records (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    period_serial_num TEXT NOT NULL CHECK (LENGTH(period_serial_num) <= 38),
                    date TEXT NOT NULL,
                    flow_level TEXT CHECK (flow_level IN ('Light', 'Medium', 'Heavy')),
                    exercise_intensity TEXT NOT NULL DEFAULT 'None' CHECK (exercise_intensity IN ('None', 'Light', 'Medium', 'Heavy')),
                    sexual_activity INTEGER NOT NULL CHECK (sexual_activity IN (0,1)),
                    diet TEXT NOT NULL CHECK (LENGTH(diet) <= 1000),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (period_serial_num)
                        REFERENCES period_records(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_period_daily_records_period ON period_daily_records(period_serial_num);
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
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    period_daily_records_serial_num TEXT NOT NULL CHECK (LENGTH(period_daily_records_serial_num) <= 38),
                    symptom_type INTEGER NOT NULL,
                    intensity INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (period_daily_records_serial_num)
                        REFERENCES period_daily_records(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_period_symptoms_daily_record ON period_symptoms(period_daily_records_serial_num);
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
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    period_serial_num TEXT NOT NULL CHECK (LENGTH(period_serial_num) <= 38),
                    start_date TEXT NOT NULL,
                    end_date TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (period_serial_num)
                        REFERENCES period_records(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_period_pms_records_period ON period_pms_records(period_serial_num);
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
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    period_pms_records_serial_num TEXT NOT NULL CHECK (LENGTH(period_pms_records_serial_num) <= 38),
                    symptom_type TEXT NOT NULL CHECK (symptom_type IN ('Pain', 'Fatigue', 'MoodSwing')),
                    intensity TEXT NOT NULL CHECK (intensity IN ('Light', 'Medium', 'Heavy')),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (period_pms_records_serial_num)
                        REFERENCES period_pms_records(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_period_pms_symptoms_pms_record ON period_pms_symptoms(period_pms_records_serial_num);
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
