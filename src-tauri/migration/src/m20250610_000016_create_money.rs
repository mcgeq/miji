// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000016_create_money.rs
// Description:    About Account Migration
// Create   Date:  2025-06-10 23:33:30
// Last Modified:  2025-06-10 23:33:42
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
use tauri_plugin_sql::Migration;

use crate::schema::MijiMigrationTrait;

pub struct CurrencyMigration;
pub struct FamilyMemberMigration;
pub struct BudgetMigration;
pub struct TransactionMigration;
pub struct BilReminderMigration;

impl MijiMigrationTrait for CurrencyMigration {
    fn up() -> Migration {
        Migration {
            version: 15,
            description: "create Currency table",
            sql: r#"
                CREATE TABLE currency (
                    code TEXT NOT NULL PRIMARY KEY,
                    symbol TEXT NOT NULL
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 15,
            description: "drop Currency table",
            sql: "DROP TABLE IF EXISTS currency;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for FamilyMemberMigration {
    fn up() -> Migration {
        Migration {
            version: 16,
            description: "create FamilyMember table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS family_member (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    name TEXT NOT NULL,
                    role TEXT NOT NULL,
                    is_primary BOOLEAN NOT NULL,
                    permissions TEXT NOT NULL,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 16,
            description: "drop FamilyMember table",
            sql: "DROP TABLE IF EXISTS family_member;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

pub struct AccountMigration;

impl MijiMigrationTrait for AccountMigration {
    fn up() -> Migration {
        Migration {
            version: 17,
            description: "create Account table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS account (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    name TEXT NOT NULL,
                    description TEXT NOT NULL,
                    balance DECIMAL NOT NULL DEFAULT 0,
                    currency TEXT NOT NULL,
                    is_shared BOOLEAN NOT NULL DEFAULT 0,
                    owner_id TEXT NOT NULL,
                    is_active BOOLEAN NOT NULL DEFAULT 1,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (currency)
                        REFERENCES currency(code)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE,
                    FOREIGN KEY (owner_id)
                        REFERENCES user(serial_num)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 17,
            description: "drop Account table",
            sql: "DROP TABLE IF EXISTS account;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for BudgetMigration {
    fn up() -> Migration {
        Migration {
            version: 18,
            description: "create Budget table",
            sql: r#"
                CREATE TABLE budget (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    account_serial_num TEXT NOT NULL,
                    name TEXT NOT NULL,
                    category TEXT NOT NULL,
                    amount DECIMAL NOT NULL DEFAULT 0,
                    repeat_period INTEGER NOT NULL DEFAULT 0,
                    start_date DATE NOT NULL,
                    end_date DATE NOT NULL,
                    used_amount DECIMAL NOT NULL DEFAULT 0,
                    is_active BOOLEAN NOT NULL DEFAULT 1,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (account_serial_num)
                        REFERENCES account(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 18,
            description: "drop Budget table",
            sql: "DROP TABLE IF EXISTS budget;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for TransactionMigration {
    fn up() -> Migration {
        Migration {
            version: 19,
            description: "create Transaction table",
            sql: r#"
                CREATE TABLE transaction (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    transaction_type INTEGER NOT NULL DEFAULT 0,
                    transaction_status INTEGER NOT NULL DEFAULT 0,
                    date DATE NOT NULL,
                    amount DECIMAL NOT NULL,
                    currency TEXT NOT NULL,
                    description TEXT NOT NULL,
                    notes TEXT,
                    account_serial_num TEXT NOT NULL,
                    category INTEGER NOT NULL,
                    sub_category TEXT,
                    tags TEXT,
                    split_members TEXT,
                    payment_method INTEGER NOT NULL DEFAULT 0,
                    actual_payer_account INTEGER NOT NULL,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (currency)
                        REFERENCES currency(code)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE,
                    FOREIGN KEY (account_serial_num)
                        REFERENCES account(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 19,
            description: "drop Transaction table",
            sql: "DROP TABLE IF EXISTS transaction;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

pub struct FamilyLedgerMigration;

impl MijiMigrationTrait for FamilyLedgerMigration {
    fn up() -> Migration {
        Migration {
            version: 20,
            description: "create FamilyLedger table",
            sql: r#"
                CREATE TABLE family_ledger (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    description TEXT NOT NULL,
                    base_currency TEXT NOT NULL,
                    members TEXT NOT NULL,
                    accounts TEXT NOT NULL,
                    transactions TEXT NOT NULL,
                    budgets TEXT NOT NULL,
                    audit_logs TEXT NOT NULL,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (base_currency)
                        REFERENCES currency(code)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 20,
            description: "drop FamilyLedger table",
            sql: "DROP TABLE IF EXISTS family_ledger;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for BilReminderMigration {
    fn up() -> Migration {
        Migration {
            version: 21,
            description: "create BilReminder table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS bil_reminder (
                    serial_num TEXT NOT NULL PRIMARY KEY,
                    name TEXT NOT NULL,
                    amount DECIMAL NOT NULL,
                    due_date DATETIME NOT NULL,
                    repeat_period INTEGER NOT NULL DEFAULT 0,
                    is_paid BOOLEAN NOT NULL,
                    related_transaction_serial_num TEXT,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME,
                    FOREIGN KEY (related_transaction_serial_num)
                        REFERENCES transaction(serial_num)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE
                );
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 21,
            description: "drop BilReminder table",
            sql: "DROP TABLE IF EXISTS bil_reminder;",
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
