pub use sea_orm_migration::prelude::*;

mod m20250420_060449_create_user_enum;
mod m20250420_060450_create_user;
mod m20250420_060451_create_project;
mod m20250420_060452_create_todos;
mod m20250420_060909_create_todos_tags;
mod m20250420_061310_create_todotags;
mod m20250420_061334_create_todo_taskdependency;
mod m20250420_061351_create_todo_attachment;
mod m20250420_061400_create_todo_reminder;
mod m20250426_071106_create_todo_project;
mod m20250525_052936_create_period_enum;
mod m20250525_053016_create_period_records;
mod m20250525_053031_create_period_daily_records;
mod m20250525_053043_create_period_symptoms;
mod m20250525_053058_create_period_pms_records;
mod m20250525_053115_create_period_pms_symptoms;
mod m20250527_000001_create_money_enum;
mod m20250527_000002_create_money_currency;
mod m20250527_000003_create_money_family_member;
mod m20250527_000004_create_money_account;
mod m20250527_000005_create_money_budget;
mod m20250527_000006_create_money_transaction;
mod m20250527_000007_create_money_family_ledger;
mod m20250527_000008_create_money_bill_reminder;
pub mod money_scheme;
pub mod period_scheme;
pub mod schema;
pub mod user_scheme;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20250420_060449_create_user_enum::Migration),
            Box::new(m20250420_060450_create_user::Migration),
            Box::new(m20250420_060451_create_project::Migration),
            Box::new(m20250420_060452_create_todos::Migration),
            Box::new(m20250420_060909_create_todos_tags::Migration),
            Box::new(m20250420_061310_create_todotags::Migration),
            Box::new(m20250420_061334_create_todo_taskdependency::Migration),
            Box::new(m20250420_061351_create_todo_attachment::Migration),
            Box::new(m20250420_061400_create_todo_reminder::Migration),
            Box::new(m20250426_071106_create_todo_project::Migration),
            Box::new(m20250525_052936_create_period_enum::Migration),
            Box::new(m20250525_053016_create_period_records::Migration),
            Box::new(m20250525_053031_create_period_daily_records::Migration),
            Box::new(m20250525_053043_create_period_symptoms::Migration),
            Box::new(m20250525_053058_create_period_pms_records::Migration),
            Box::new(m20250525_053115_create_period_pms_symptoms::Migration),
            Box::new(m20250527_000001_create_money_enum::Migration),
            Box::new(m20250527_000002_create_money_currency::Migration),
            Box::new(m20250527_000003_create_money_family_member::Migration),
            Box::new(m20250527_000004_create_money_account::Migration),
            Box::new(m20250527_000005_create_money_budget::Migration),
            Box::new(m20250527_000006_create_money_transaction::Migration),
            Box::new(m20250527_000007_create_money_family_ledger::Migration),
            Box::new(m20250527_000008_create_money_bill_reminder::Migration),
        ]
    }
}
