pub use sea_orm_migration::prelude::*;

mod m20250101_000000_insert_default_user;
mod m20250101_120000_add_is_virtual_to_account;
mod m20250102_000000_add_installment_fields_to_transactions;
mod m20250115_000001_enhance_todo_reminder_fields;
mod m20250115_000002_enhance_bil_reminder_fields;
mod m20250115_000003_enhance_reminder_fields;
mod m20250115_000004_create_notification_tables;
mod m20250116_000000_create_installment_tables;
mod m20250120_000000_add_phone_bill_subcategory;
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
mod m20250916_221212_create_categories;
mod m20250918_115414_create_categories_alert;
mod m20250918_121424_create_sub_categories_alert;
mod m20250924_184622_create_bil_reminder_alter;
mod m20250924_185222_create_budget_alert;
mod m20250929_110022_create_todo_alert;
mod m20250929_120022_create_todo_drop;
mod m20250929_121722_create_todo_repeat_period_type;
mod m20251017_160622_create_transaction_alert;
mod m20251112_000001_enhance_family_ledger_fields;
mod m20251112_000002_enhance_family_member_fields;
mod m20251112_000003_create_split_rules_table;
mod m20251112_000004_create_split_records_table;
mod m20251112_000005_create_debt_relations_table;
mod m20251112_000006_create_settlement_records_table;
mod m20251115_000000_add_settlement_day_to_family_ledger;
mod m20251115_000007_change_family_ledger_counts_to_integer;
mod m20251116_000001_add_family_ledger_financial_stats;
mod m20251116_000007_enhance_budget_for_family;
mod m20251116_add_unique_constraint_family_member_name;
mod m20251116_create_split_record_details;
mod m20251116_drop_split_members;
mod m20251916_221213_create_sub_categories;
mod m20251917_223412_create_sub_category_insert;
mod m20251918_120000_add_sub_category_property_rental;

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
            Box::new(m20250101_120000_add_is_virtual_to_account::Migration),
            Box::new(m20250803_132130_create_budget::Migration),
            Box::new(m20250803_132157_create_transactions::Migration),
            Box::new(m20250803_132219_create_family_ledger::Migration),
            Box::new(m20250803_132247_create_family_ledger_account::Migration),
            Box::new(m20250803_132301_create_family_ledger_transaction::Migration),
            Box::new(m20250803_132314_create_family_ledger_member::Migration),
            Box::new(m20250803_132329_create_bil_reminder::Migration),
            Box::new(m20250914_212312_create_health_period_settings::Migration),
            Box::new(m20250916_221212_create_categories::Migration),
            Box::new(m20251916_221213_create_sub_categories::Migration),
            Box::new(m20251917_223412_create_sub_category_insert::Migration),
            Box::new(m20251918_120000_add_sub_category_property_rental::Migration),
            Box::new(m20250120_000000_add_phone_bill_subcategory::Migration),
            Box::new(m20250918_115414_create_categories_alert::Migration),
            Box::new(m20250918_121424_create_sub_categories_alert::Migration),
            Box::new(m20250924_184622_create_bil_reminder_alter::Migration),
            Box::new(m20250924_185222_create_budget_alert::Migration),
            Box::new(m20250929_120022_create_todo_drop::Migration),
            Box::new(m20250929_110022_create_todo_alert::Migration),
            Box::new(m20250929_121722_create_todo_repeat_period_type::Migration),
            Box::new(m20250101_000000_insert_default_user::Migration),
            Box::new(m20250102_000000_add_installment_fields_to_transactions::Migration),
            Box::new(m20250116_000000_create_installment_tables::Migration),
            Box::new(m20251017_160622_create_transaction_alert::Migration),
            Box::new(m20250115_000001_enhance_todo_reminder_fields::Migration),
            Box::new(m20250115_000002_enhance_bil_reminder_fields::Migration),
            Box::new(m20250115_000003_enhance_reminder_fields::Migration),
            Box::new(m20250115_000004_create_notification_tables::Migration),
            // 新增的家庭账本功能迁移
            Box::new(m20251112_000001_enhance_family_ledger_fields::Migration),
            Box::new(m20251112_000002_enhance_family_member_fields::Migration),
            Box::new(m20251112_000003_create_split_rules_table::Migration),
            Box::new(m20251112_000004_create_split_records_table::Migration),
            Box::new(m20251112_000005_create_debt_relations_table::Migration),
            Box::new(m20251112_000006_create_settlement_records_table::Migration),
            Box::new(m20251115_000000_add_settlement_day_to_family_ledger::Migration),
            Box::new(m20251115_000007_change_family_ledger_counts_to_integer::Migration),
            Box::new(m20251116_000001_add_family_ledger_financial_stats::Migration),
            // 废弃 split_members JSON 字段，使用 split_records 表
            Box::new(m20251116_drop_split_members::Migration),
            // 为 family_member.name 添加唯一约束
            Box::new(m20251116_add_unique_constraint_family_member_name::Migration),
            Box::new(m20251116_create_split_record_details::Migration),
            // Phase 6: 扩展Budget表支持家庭预算
            Box::new(m20251116_000007_enhance_budget_for_family::Migration),
        ]
    }
}
