pub use sea_orm_migration::prelude::*;

// 重构后的迁移文件 - 一表一文件结构
mod m20251122_001_create_users;
mod m20251122_002_create_currency;
mod m20251122_003_create_account;
mod m20251122_004_create_categories;
mod m20251122_005_create_sub_categories;
mod m20251122_006_create_transactions;
mod m20251122_007_create_budget;
mod m20251122_008_create_budget_allocations;
mod m20251122_009_create_installment_plans;
mod m20251122_010_create_installment_details;
mod m20251122_011_create_family_ledger;
mod m20251122_012_create_family_member;
mod m20251122_013_create_family_ledger_account;
mod m20251122_014_create_family_ledger_transaction;
mod m20251122_015_create_family_ledger_member;
mod m20251122_016_create_split_rules;
mod m20251122_017_create_split_records;
mod m20251122_018_create_split_record_details;
mod m20251122_019_create_debt_relations;
mod m20251122_020_create_settlement_records;
mod m20251122_021_create_bil_reminder;
mod m20251122_022_create_project;
mod m20251122_023_create_tag;
mod m20251122_024_create_todo;
mod m20251122_025_027_create_todo_relations;
mod m20251122_028_create_attachment;
mod m20251122_029_create_reminder;
mod m20251122_030_032_create_notifications;
mod m20251122_033_038_create_health_period;
mod m20251122_039_create_operation_log;
mod m20251202_040_create_user_settings;
mod m20251202_041_create_user_setting_profiles;
mod m20251202_042_create_user_setting_history;
mod m20251206_043_add_priority_to_notification_logs;
mod m20251206_044_create_scheduler_config;
mod m20251206_046_create_project_tag;

pub mod schema;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20251122_001_create_users::Migration),
            Box::new(m20251122_002_create_currency::Migration),
            Box::new(m20251122_003_create_account::Migration),
            Box::new(m20251122_004_create_categories::Migration),
            Box::new(m20251122_005_create_sub_categories::Migration),
            Box::new(m20251122_006_create_transactions::Migration),
            Box::new(m20251122_007_create_budget::Migration),
            Box::new(m20251122_008_create_budget_allocations::Migration),
            Box::new(m20251122_009_create_installment_plans::Migration),
            Box::new(m20251122_010_create_installment_details::Migration),
            Box::new(m20251122_011_create_family_ledger::Migration),
            Box::new(m20251122_012_create_family_member::Migration),
            Box::new(m20251122_013_create_family_ledger_account::Migration),
            Box::new(m20251122_014_create_family_ledger_transaction::Migration),
            Box::new(m20251122_015_create_family_ledger_member::Migration),
            Box::new(m20251122_016_create_split_rules::Migration),
            Box::new(m20251122_017_create_split_records::Migration),
            Box::new(m20251122_018_create_split_record_details::Migration),
            Box::new(m20251122_019_create_debt_relations::Migration),
            Box::new(m20251122_020_create_settlement_records::Migration),
            Box::new(m20251122_021_create_bil_reminder::Migration),
            Box::new(m20251122_022_create_project::Migration),
            Box::new(m20251122_023_create_tag::Migration),
            Box::new(m20251122_024_create_todo::Migration),
            Box::new(m20251122_025_027_create_todo_relations::Migration),
            Box::new(m20251122_028_create_attachment::Migration),
            Box::new(m20251122_029_create_reminder::Migration),
            Box::new(m20251122_030_032_create_notifications::Migration),
            Box::new(m20251122_033_038_create_health_period::Migration),
            Box::new(m20251122_039_create_operation_log::Migration),
            Box::new(m20251202_040_create_user_settings::Migration),
            Box::new(m20251202_041_create_user_setting_profiles::Migration),
            Box::new(m20251202_042_create_user_setting_history::Migration),
            Box::new(m20251206_043_add_priority_to_notification_logs::Migration),
            Box::new(m20251206_044_create_scheduler_config::Migration),
            Box::new(m20251206_046_create_project_tag::Migration),
        ]
    }
}
