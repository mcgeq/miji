pub use sea_orm_migration::prelude::*;

mod m20250803_114611_create_user;
mod m20250803_122150_create_tags;
mod m20250803_122206_create_projects;
mod m20250803_124210_create_todo;
mod m20250803_124220_create_todo_project;
mod m20250803_124230_create_todo_tag;
mod m20250803_124248_create_operation_log;
mod m20250803_124310_create_health_period;
mod m20250803_125402_create_health_period_daily_records;
mod m20250803_125420_create_health_period_symptoms;
mod m20250803_125442_create_health_period_pms_records;
mod m20250803_125454_create_health_period_pms_symptoms;
mod m20250803_131019_create_task_dependency;
mod m20250803_131035_create_task_attachment;
mod m20250803_131055_create_reminder;
mod m20250803_132058_create_currency;
mod m20250803_132113_create_family_member;
mod m20250803_132124_create_account;
mod m20250803_132130_create_budget;
mod m20250803_132157_create_transactions;
mod m20250803_132219_create_family_ledger;
mod m20250803_132247_create_family_ledger_account;
mod m20250803_132301_create_family_ledger_transaction;
mod m20250803_132314_create_family_ledger_member;
mod m20250803_132329_create_bil_reminder;
mod m20250914_212312_create_health_period_settings;

pub mod schema;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20250803_114611_create_user::Migration),
            Box::new(m20250803_122150_create_tags::Migration),
            Box::new(m20250803_122206_create_projects::Migration),
            Box::new(m20250803_124210_create_todo::Migration),
            Box::new(m20250803_124220_create_todo_project::Migration),
            Box::new(m20250803_124230_create_todo_tag::Migration),
            Box::new(m20250803_124248_create_operation_log::Migration),
            Box::new(m20250803_124310_create_health_period::Migration),
            Box::new(m20250803_125402_create_health_period_daily_records::Migration),
            Box::new(m20250803_125420_create_health_period_symptoms::Migration),
            Box::new(m20250803_125442_create_health_period_pms_records::Migration),
            Box::new(m20250803_125454_create_health_period_pms_symptoms::Migration),
            Box::new(m20250803_131019_create_task_dependency::Migration),
            Box::new(m20250803_131035_create_task_attachment::Migration),
            Box::new(m20250803_131055_create_reminder::Migration),
            Box::new(m20250803_132058_create_currency::Migration),
            Box::new(m20250803_132113_create_family_member::Migration),
            Box::new(m20250803_132124_create_account::Migration),
            Box::new(m20250803_132130_create_budget::Migration),
            Box::new(m20250803_132157_create_transactions::Migration),
            Box::new(m20250803_132219_create_family_ledger::Migration),
            Box::new(m20250803_132247_create_family_ledger_account::Migration),
            Box::new(m20250803_132301_create_family_ledger_transaction::Migration),
            Box::new(m20250803_132314_create_family_ledger_member::Migration),
            Box::new(m20250803_132329_create_bil_reminder::Migration),
            Box::new(m20250914_212312_create_health_period_settings::Migration),
        ]
    }
}
