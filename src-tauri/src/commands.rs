// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    统一的命令注册器
// Create   Date:  2025-06-15 15:49:12
// Last Modified:  2025-11-11
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use auth::commands as auth_cmd;
use healths::command as health_cmd;
use money::command as money_cmd;
use tauri::{Builder, Wry};
use todos::command as todo_cmd;

// 重新导出system_commands中的类型供外部使用
pub use crate::system_commands::{set_complete, AppPreferences};

/// 注册所有Tauri命令
pub fn init_commands(builder: Builder<Wry>) -> Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![
        // 系统命令
        crate::system_commands::set_complete,
        crate::system_commands::greet,
        crate::system_commands::pwd_hash,
        crate::system_commands::check_pwd,
        crate::system_commands::generate_token,
        crate::system_commands::is_verify_token,
        crate::system_commands::minimize_to_tray,
        crate::system_commands::restore_from_tray,
        crate::system_commands::toggle_window_visibility,
        crate::system_commands::close_app,
        crate::system_commands::get_close_behavior_preference,
        crate::system_commands::set_close_behavior_preference,
        crate::system_commands::is_user_logged_in,
        // 认证命令
        auth_cmd::exists_user,
        auth_cmd::create_user,
        auth_cmd::get_user_with_email,
        auth_cmd::update_user,
        // 待办命令
        todo_cmd::todo_get,
        todo_cmd::todo_create,
        todo_cmd::todo_update,
        todo_cmd::todo_delete,
        todo_cmd::todo_toggle,
        todo_cmd::todo_list,
        todo_cmd::todo_list_paged,
        // 财务命令
        money_cmd::total_assets,
        money_cmd::account_get,
        money_cmd::account_create,
        money_cmd::account_update,
        money_cmd::account_update_active,
        money_cmd::account_delete,
        money_cmd::account_list,
        money_cmd::account_list_paged,
        money_cmd::currency_create,
        money_cmd::currency_get,
        money_cmd::currency_update,
        money_cmd::currency_delete,
        money_cmd::currencies_list,
        money_cmd::currencies_list_paged,
        money_cmd::transaction_create,
        money_cmd::transaction_transfer_create,
        money_cmd::transaction_transfer_delete,
        money_cmd::transaction_transfer_update,
        money_cmd::transaction_query_income_and_expense,
        money_cmd::transaction_get_stats,
        money_cmd::transaction_get,
        money_cmd::transaction_update,
        money_cmd::transaction_delete,
        money_cmd::transaction_list,
        money_cmd::transaction_list_paged,
        money_cmd::installment_plan_get,
        money_cmd::installment_calculate,
        money_cmd::installment_has_paid,
        money_cmd::budget_get,
        money_cmd::budget_create,
        money_cmd::budget_update,
        money_cmd::budget_update_active,
        money_cmd::budget_delete,
        money_cmd::budget_list_paged,
        money_cmd::budget_overview_calculate,
        money_cmd::budget_overview_by_type,
        money_cmd::budget_overview_by_scope,
        money_cmd::budget_trends_get,
        money_cmd::budget_category_stats_get,
        money_cmd::bil_reminder_get,
        money_cmd::bil_reminder_create,
        money_cmd::bil_reminder_update,
        money_cmd::bil_reminder_update_active,
        money_cmd::bil_reminder_delete,
        money_cmd::bil_reminder_list,
        money_cmd::bil_reminder_list_paged,
        money_cmd::category_get,
        money_cmd::category_create,
        money_cmd::category_update,
        money_cmd::category_delete,
        money_cmd::category_list,
        money_cmd::category_list_paged,
        money_cmd::sub_category_get,
        money_cmd::sub_category_create,
        money_cmd::sub_category_update,
        money_cmd::sub_category_delete,
        money_cmd::sub_category_list,
        money_cmd::sub_category_list_paged,
        money_cmd::family_member_list,
        money_cmd::family_ledger_list,
        money_cmd::family_ledger_get,
        money_cmd::family_ledger_create,
        money_cmd::family_ledger_update,
        money_cmd::family_ledger_delete,
        money_cmd::family_ledger_stats,
        // 健康命令
        health_cmd::period_record_create,
        health_cmd::period_record_update,
        health_cmd::period_record_delete,
        health_cmd::period_record_list_paged,
        health_cmd::period_daily_record_get,
        health_cmd::period_daily_record_create,
        health_cmd::period_daily_record_update,
        health_cmd::period_daily_record_delete,
        health_cmd::period_daily_record_list_paged,
        health_cmd::period_settings_get,
        health_cmd::period_settings_create,
        health_cmd::period_settings_update,
    ])
}
