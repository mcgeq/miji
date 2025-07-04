// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           migrations.rs
// Description:    About Sqlite Migrations
// Create   Date:  2025-06-10 19:40:47
// Last Modified:  2025-06-14 22:31:42
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use migration::{
    m20250610_000001_create_user::UserMigration,
    m20250610_000002_create_project::{ProjectMigration, TodoProjectMigration},
    m20250610_000003_create_todos::{
        AttachmentMigration, ReminderMigration, TaskDependencyMigration, TodoMigration,
        TodoTagMigration,
    },
    m20250610_000004_create_tags::TagMigration,
    m20250610_000011_create_period::{
        PeriodDailyRecordsMigration, PeriodPmsRecordsMigration, PeriodPmsSymptomsMigration,
        PeriodRecordsMigration, PeriodSymptomsMigration,
    },
    m20250610_000016_create_money::{
        AccountMigration, BilReminderMigration, BudgetMigration, CurrencyMigration,
        FamilyLedgerAccountMigration, FamilyLedgerMemberMigration, FamilyLedgerMigration,
        FamilyLedgerTransactionMigration, FamilyMemberMigration, TransactionMigration,
    },
    schema::MijiMigrationTrait,
};
use tauri::Runtime;

pub trait MijiMigrations {
    fn init_migrations(self) -> Self;
}

impl<R: Runtime> MijiMigrations for tauri::Builder<R> {
    fn init_migrations(self) -> Self {
        let mig = vec![
            UserMigration::up(),
            ProjectMigration::up(),
            TagMigration::up(),
            TodoMigration::up(),
            ReminderMigration::up(),
            TodoTagMigration::up(),
            AttachmentMigration::up(),
            TodoProjectMigration::up(),
            TaskDependencyMigration::up(),
            PeriodPmsSymptomsMigration::up(),
            PeriodSymptomsMigration::up(),
            PeriodRecordsMigration::up(),
            PeriodDailyRecordsMigration::up(),
            PeriodPmsRecordsMigration::up(),
            CurrencyMigration::up(),
            FamilyMemberMigration::up(),
            FamilyLedgerMigration::up(),
            FamilyLedgerMemberMigration::up(),
            BudgetMigration::up(),
            TransactionMigration::up(),
            AccountMigration::up(),
            BilReminderMigration::up(),
            FamilyLedgerAccountMigration::up(),
            FamilyLedgerTransactionMigration::up(),
        ];
        self.plugin(
            tauri_plugin_sql::Builder::default()
                .add_migrations("sqlite:miji.db", mig)
                .build(),
        )
    }
}
