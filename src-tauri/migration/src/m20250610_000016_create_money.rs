// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           m20250610_000016_create_money.rs
// Description:    About Account Migration
// Create   Date:  2025-06-10 23:33:30
// Last Modified:  2025-06-25 22:25:44
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use crate::schema::MijiMigrationTrait;
use tauri_plugin_sql::Migration;

pub struct AccountMigration;
pub struct CurrencyMigration;
pub struct FamilyMemberMigration;
pub struct BudgetMigration;
pub struct TransactionMigration;
pub struct BilReminderMigration;
pub struct FamilyLedgerMemberMigration;
pub struct FamilyLedgerAccountMigration;
pub struct FamilyLedgerTransactionMigration;
pub struct FamilyLedgerMigration;

impl MijiMigrationTrait for CurrencyMigration {
    fn up() -> Migration {
        Migration {
            version: 15,
            description: "create Currency table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS currency (
                    code TEXT PRIMARY KEY CHECK (LENGTH(code) = 3),
                    locale TEXT NOT NULL,
                    symbol TEXT NOT NULL CHECK (LENGTH(symbol) <= 10),
                    created_at TEXT NOT NULL,
                    updated_at TEXT
                );
                INSERT INTO currency (
                    code, 
                    locale, 
                    symbol, 
                    created_at
                ) VALUES
                    ('USD', 'en-US', '$',  '2025-07-26T13:13:24.487000+08:00'),
                    ('EUR', 'en-EU', '€',  '2025-07-26T13:13:24.487000+08:00'),
                    ('CNY', 'zh-CN', '¥',  '2025-07-26T13:13:24.487000+08:00'),
                    ('GBP', 'en-GB', '£',  '2025-07-26T13:13:24.487000+08:00'),
                    ('JPY', 'ja-JP', '¥',  '2025-07-26T13:13:24.487000+08:00'),
                    ('AUD', 'en-AU', '$',  '2025-07-26T13:13:24.487000+08:00'),
                    ('CAD', 'en-CA', '$',  '2025-07-26T13:13:24.487000+08:00'),
                    ('CHF', 'en-CH', 'CHF',  '2025-07-26T13:13:24.487000+08:00'),
                    ('SEK', 'sv-SE', 'kr',  '2025-07-26T13:13:24.487000+08:00'),
                    ('INR', 'hi-IN', '₹',  '2025-07-26T13:13:24.487000+08:00');
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
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    name TEXT NOT NULL CHECK (LENGTH(name) <= 100),
                    role TEXT NOT NULL DEFAULT 'Member' CHECK (role IN ('Admin', 'Member', 'Owner', 'Viewer')),
                    is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0,1)),
                    permissions TEXT NOT NULL CHECK (LENGTH(permissions) <= 500),
                    created_at TEXT NOT NULL,
                    updated_at TEXT
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

impl MijiMigrationTrait for AccountMigration {
    fn up() -> Migration {
        Migration {
            version: 17,
            description: "create Account table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS account (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    name TEXT NOT NULL CHECK (LENGTH(name) <= 200),
                    description TEXT NOT NULL CHECK (LENGTH(description) <= 1000),
                    type TEXT NOT NULL CHECK (type IN ('Savings', 'Cash', 'Bank', 'CreditCard', 'Investment', 'Alipay', 'WeChat', 'CloudQuickPass', 'Other')),
                    balance DECIMAL NOT NULL DEFAULT 0,
                    initial_balance DECIMAL NOT NULL DEFAULT 0,
                    currency TEXT NOT NULL CHECK (LENGTH(currency) = 3),
                    is_shared INTEGER NOT NULL DEFAULT 0 CHECK (is_shared IN (0,1)),
                    owner_id TEXT CHECK (LENGTH(owner_id) <= 38),
                    color TEXT,
                    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (currency)
                        REFERENCES currency(code)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE,
                    FOREIGN KEY (owner_id)
                        REFERENCES family_member(serial_num)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_account_owner ON account(owner_id);
                CREATE INDEX IF NOT EXISTS idx_account_currency ON account(currency);
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
                CREATE TABLE IF NOT EXISTS budget (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    account_serial_num TEXT NOT NULL CHECK (LENGTH(account_serial_num) <= 38),
                    name TEXT NOT NULL CHECK (LENGTH(name) <= 200),
                    category TEXT NOT NULL CHECK (category IN ('Food', 'Transport', 'Entertainment', 'Utilities', 'Shopping', 'Salary', 'Investment', 'Others')),
                    amount DECIMAL NOT NULL DEFAULT 0,
                    currency TEXT NOT NULL CHECK (LENGTH(currency) <= 10),
                    repeat_period TEXT NOT NULL,
                    start_date TEXT NOT NULL,
                    end_date TEXT NOT NULL,
                    used_amount DECIMAL NOT NULL DEFAULT 0,
                    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
                    alert_enabled INTEGER NOT NULL DEFAULT 0 CHECK (alert_enabled IN (0,1)),
                    alert_threshold TEXT,
                    color TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (account_serial_num)
                        REFERENCES account(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_budget_account ON budget(account_serial_num);
                CREATE INDEX IF NOT EXISTS idx_budget_category ON budget(category);
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
                CREATE TABLE IF NOT EXISTS transactions (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    transaction_type TEXT NOT NULL DEFAULT 'Income' CHECK (transaction_type IN ('Income', 'Expense')),
                    transaction_status TEXT NOT NULL DEFAULT 'Pending' CHECK (transaction_status IN ('Pending', 'Completed', 'Reversed')),
                    date TEXT NOT NULL,
                    amount DECIMAL NOT NULL,
                    currency TEXT NOT NULL CHECK (LENGTH(currency) <= 10),
                    description TEXT NOT NULL CHECK (LENGTH(description) <= 1000),
                    notes TEXT CHECK (LENGTH(notes) <= 2000),
                    account_serial_num TEXT NOT NULL CHECK (LENGTH(account_serial_num) <= 38),
                    category TEXT NOT NULL CHECK (category IN ('Food','Transport','Entertainment','Utilities','Shopping','Salary','Investment','Transfer','Education','Healthcare','Insurance','Savings','Gift','Loan','Business','Travel','Charity','Subscription','Pet','Home','Others')),
                    sub_category TEXT CHECK (sub_category IN ('Restaurant', 'Groceries', 'Snacks', 'Bus', 'Taxi', 'Fuel', 'Movies', 'Concerts', 'MonthlySalary', 'Bonus', 'Other') OR sub_category IS NULL),
                    tags TEXT CHECK (LENGTH(tags) <= 500),
                    split_members TEXT,
                    payment_method TEXT NOT NULL DEFAULT 'Cash' CHECK (payment_method IN ('Cash', 'BankTransfer', 'CreditCard', 'WeChat', 'Alipay', 'Other')),
                    actual_payer_account TEXT NOT NULL CHECK (LENGTH(actual_payer_account) <= 38),
                    related_transaction_serial_num TEXT CHECK (LENGTH(actual_payer_account) <= 38),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (currency)
                        REFERENCES currency(code)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE,
                    FOREIGN KEY (account_serial_num)
                        REFERENCES account(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_transaction_date ON transactions(date);
                CREATE INDEX IF NOT EXISTS idx_transaction_category ON transactions(category);
                CREATE INDEX IF NOT EXISTS idx_transaction_account ON transactions(account_serial_num);
                CREATE INDEX IF NOT EXISTS idx_transaction_category_date ON transactions(category, date);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 19,
            description: "drop Transaction table",
            sql: r#"
                DROP INDEX IF EXISTS idx_transaction_date;
                DROP INDEX IF EXISTS idx_transaction_category;
                DROP INDEX IF EXISTS idx_transaction_account;
                DROP TABLE IF EXISTS transactions;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for FamilyLedgerMigration {
    fn up() -> Migration {
        Migration {
            version: 20,
            description: "create FamilyLedger table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS family_ledger (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    name TEXT,
                    description TEXT NOT NULL CHECK (LENGTH(description) <= 1000),
                    base_currency TEXT NOT NULL CHECK (LENGTH(base_currency) <= 10),
                    members TEXT,
                    accounts TEXT,
                    transactions TEXT,
                    budgets TEXT,
                    audit_logs TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
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

impl MijiMigrationTrait for FamilyLedgerAccountMigration {
    fn up() -> Migration {
        Migration {
            version: 21,
            description: "create FamilyLedgerAccount table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS family_ledger_account (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    family_ledger_serial_num TEXT NOT NULL CHECK (LENGTH(family_ledger_serial_num) <= 38),
                    account_serial_num TEXT NOT NULL CHECK (LENGTH(account_serial_num) <= 38),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (family_ledger_serial_num)
                        REFERENCES family_ledger(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE,
                    FOREIGN KEY (account_serial_num)
                        REFERENCES account(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_family_ledger_account_ledger ON family_ledger_account(family_ledger_serial_num);
                CREATE INDEX IF NOT EXISTS idx_family_ledger_account_account ON family_ledger_account(account_serial_num);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }
    fn down() -> Migration {
        Migration {
            version: 21,
            description: "drop FamilyLedgerAccount table",
            sql: r#"
                DROP INDEX IF EXISTS idx_family_ledger_account_ledger;
                DROP INDEX IF EXISTS idx_family_ledger_account_account;
                DROP TABLE IF EXISTS family_ledger_account;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for FamilyLedgerTransactionMigration {
    fn up() -> Migration {
        Migration {
            version: 22,
            description: "create FamilyLedgerTransaction association table for many-to-many relation",
            sql: r#"
                CREATE TABLE IF NOT EXISTS family_ledger_transaction (
                    family_ledger_serial_num TEXT NOT NULL CHECK (LENGTH(family_ledger_serial_num) <= 38),
                    transaction_serial_num TEXT NOT NULL CHECK (LENGTH(transaction_serial_num) <= 38),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    PRIMARY KEY (family_ledger_serial_num, transaction_serial_num),
                    FOREIGN KEY (family_ledger_serial_num)
                        REFERENCES family_ledger(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE,
                    FOREIGN KEY (transaction_serial_num)
                        REFERENCES transactions(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_family_ledger_transaction_ledger ON family_ledger_transaction(family_ledger_serial_num);
                CREATE INDEX IF NOT EXISTS idx_family_ledger_transaction_transaction ON family_ledger_transaction(transaction_serial_num);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }
    fn down() -> Migration {
        Migration {
            version: 22,
            description: "drop FamilyLedgerTransaction association table",
            sql: r#"
                DROP INDEX IF EXISTS idx_family_ledger_transaction_ledger;
                DROP INDEX IF EXISTS idx_family_ledger_transaction_transaction;
                DROP TABLE IF EXISTS family_ledger_transaction;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for FamilyLedgerMemberMigration {
    fn up() -> Migration {
        Migration {
            version: 23,
            description: "create FamilyLedgerMember association table for many-to-many relation",
            sql: r#"
                CREATE TABLE IF NOT EXISTS family_ledger_member (
                    family_ledger_serial_num TEXT NOT NULL CHECK (LENGTH(family_ledger_serial_num) <= 38),
                    family_member_serial_num TEXT NOT NULL CHECK (LENGTH(family_member_serial_num) <= 38),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    PRIMARY KEY (family_ledger_serial_num, family_member_serial_num),
                    FOREIGN KEY (family_ledger_serial_num)
                        REFERENCES family_ledger(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE,
                    FOREIGN KEY (family_member_serial_num)
                        REFERENCES family_member(serial_num)
                        ON DELETE CASCADE
                        ON UPDATE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_family_ledger_member_ledger ON family_ledger_member(family_ledger_serial_num);
                CREATE INDEX IF NOT EXISTS idx_family_ledger_member_member ON family_ledger_member(family_member_serial_num);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }
    fn down() -> Migration {
        Migration {
            version: 23,
            description: "drop FamilyLedgerMember association table",
            sql: r#"
                DROP INDEX IF EXISTS idx_family_ledger_member_ledger;
                DROP INDEX IF EXISTS idx_family_ledger_member_member;
                DROP TABLE IF EXISTS family_ledger_member;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}

impl MijiMigrationTrait for BilReminderMigration {
    fn up() -> Migration {
        Migration {
            version: 24,
            description: "create bil_reminder table",
            sql: r#"
                CREATE TABLE IF NOT EXISTS bil_reminder (
                    serial_num TEXT NOT NULL PRIMARY KEY CHECK (LENGTH(serial_num) <= 38),
                    name TEXT NOT NULL,
                    enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
                    type TEXT NOT NULL CHECK (type IN ('Notification', 'Email', 'Popup')),
                    description TEXT NOT NULL CHECK (LENGTH(description) <= 1000),
                    category TEXT NOT NULL CHECK (category IN ('Food', 'Transport', 'Entertainment', 'Utilities', 'Shopping', 'Salary', 'Investment', 'Others')),
                    amount TEXT NOT NULL CHECK (amount GLOB '[0-9]*\\.?[0-9]*'),
                    currency TEXT NOT NULL CHECK (LENGTH(currency) <= 10),
                    due_at TEXT NOT NULL,
                    bill_date TEXT NOT NULL,
                    remind_date TEXT NOT NULL,
                    repeat_period TEXT NOT NULL,
                    is_paid INTEGER NOT NULL DEFAULT 1 CHECK (is_paid IN (0,1)),
                    priority TEXT NOT NULL DEFAULT 'Low' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
                    advance_value INTEGER,
                    advance_unit TEXT,
                    related_transaction_serial_num TEXT CHECK (LENGTH(related_transaction_serial_num) <= 38),
                    color TEXT,
                    is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
                    created_at TEXT NOT NULL,
                    updated_at TEXT,
                    FOREIGN KEY (related_transaction_serial_num)
                        REFERENCES transactions(serial_num)
                        ON DELETE RESTRICT
                        ON UPDATE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_bil_reminder_due_at ON bil_reminder (due_at);
                CREATE INDEX IF NOT EXISTS idx_bil_reminder_paid ON bil_reminder (is_paid);
            "#,
            kind: tauri_plugin_sql::MigrationKind::Up,
        }
    }

    fn down() -> Migration {
        Migration {
            version: 24,
            description: "drop bil_reminder table and indexes",
            sql: r#"
                DROP INDEX IF EXISTS idx_bil_reminder_due_at;
                DROP INDEX IF EXISTS idx_bil_reminder_paid;
                DROP TABLE IF EXISTS bil_reminder;
            "#,
            kind: tauri_plugin_sql::MigrationKind::Down,
        }
    }
}
