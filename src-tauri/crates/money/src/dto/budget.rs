use chrono::{DateTime, FixedOffset, NaiveDate, Utc};
use common::{
    crud::service::parse_json_field,
    utils::{date::DateUtils, uuid::McgUuid, validate::validate_color},
};
use sea_orm::{ActiveValue, prelude::Decimal};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::dto::{
    account::{AccountResponseWithRelations, AccountType, AccountWithRelations},
    currency::CurrencyResponse,
};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")] // 注意要和前端 z.enum 值匹配大小写
pub enum Weekday {
    Mon,
    Tue,
    Wed,
    Thu,
    Fri,
    Sat,
    Sun,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum MonthlyDay {
    Day(u8),
    Last,
}

// 重复类型
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum RepeatPeriod {
    None,
    Daily {
        interval: u32,
    },
    Weekly {
        interval: u32,
        days_of_week: Vec<Weekday>,
    },
    Monthly {
        interval: u32,
        day: MonthlyDay,
    },
    Yearly {
        interval: u32,
        month: u8,
        day: u8,
    },
    Custom {
        description: String,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum AlertThreshold {
    Percentage(Decimal),  // 0-100 百分比
    FixedAmount(Decimal), // 固定金额阈值
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")] // 注意要和前端 z.enum 值匹配大小写
pub enum BudgetType {
    Standard,      // 标准预算
    SavingGoal,    // 储蓄目标
    DebtRepayment, // 债务偿还
    Project,       // 项目预算
    Investment,    // 投资预算
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Reminder {
    pub reminder_type: ReminderType,
    pub days_before: Option<u8>,    // 提前几天提醒
    pub threshold: Option<Decimal>, // 阈值提醒
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")] // 注意要和前端 z.enum 值匹配大小写
pub enum ReminderType {
    ThresholdAlert,  // 阈值提醒
    PeriodEnd,       // 周期结束提醒
    ResetReminder,   // 重置提醒
    ContributionDue, // 供款到期
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RolloverRecord {
    pub from_period: NaiveDate,   // 原周期开始
    pub to_period: NaiveDate,     // 新周期开始
    pub amount: Decimal,          // 滚动金额
    pub timestamp: DateTime<Utc>, // 滚动时间
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SharingSettings {
    pub shared_with: Vec<String>, // 共享用户ID列表
    pub permission_level: SharingPermission,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")] // 注意要和前端 z.enum 值匹配大小写
pub enum SharingPermission {
    ViewOnly,   // 仅查看
    Contribute, // 可添加交易
    Manage,     // 完全管理
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Attachment {
    pub id: String,        // 附件ID
    pub name: String,      // 文件名
    pub mime_type: String, // MIME类型
    pub size: u32,         // 文件大小(KB)
    pub uploaded_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum BudgetScopeType {
    Category,  // 仅分类
    Account,   // 仅账户
    Hybrid,    // 混合模式
    RuleBased, // 规则引擎
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AccountScope {
    pub included_accounts: Vec<String>,
    pub excluded_accounts: Option<Vec<String>>,
    pub account_types: Option<Vec<AccountType>>,
    pub include_all_of_type: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CategoryScope {
    pub included_categories: Vec<String>,
    pub excluded_categories: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum BudgetRuleType {
    DescriptionContains,
    AmountGreaterThan,
    AmountLessThan,
    HasTag,
    PaymentMethod,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetRule {
    pub rule_type: BudgetRuleType,
    pub value: String,         // 或 serde_json::Value 根据具体类型
    pub inverse: Option<bool>, // 是否反向匹配
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BudgetBase {
    #[validate(length(equal = 38))]
    pub account_serial_num: Option<String>,
    #[validate(length(min = 2, max = 20))]
    pub name: String,
    pub description: Option<String>,
    pub amount: Decimal,
    pub repeat_period_type: String,
    pub repeat_period: serde_json::Value,
    pub start_date: DateTime<FixedOffset>,
    pub end_date: DateTime<FixedOffset>,
    pub used_amount: Decimal,
    pub is_active: bool,
    pub alert_enabled: bool,
    pub alert_threshold: Option<serde_json::Value>,
    #[validate(custom(function = "validate_color"))]
    pub color: Option<String>,
    pub current_period_used: Decimal,
    pub current_period_start: NaiveDate,
    pub budget_type: String,
    pub progress: Decimal,
    pub linked_goal: Option<String>,
    pub reminders: Option<serde_json::Value>,
    pub priority: i8,
    pub tags: Option<serde_json::Value>,
    pub auto_rollover: bool,
    pub rollover_history: Option<serde_json::Value>,
    pub sharing_settings: Option<serde_json::Value>,
    pub attachments: Option<serde_json::Value>,
    pub budget_scope_type: String,
    pub account_scope: Option<serde_json::Value>,
    pub category_scope: Option<serde_json::Value>,
    pub advanced_rules: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetWithAccount {
    pub budget: entity::budget::Model,
    pub account: Option<AccountWithRelations>,
    pub currency: entity::currency::Model,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct Budget {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: BudgetBase,
    pub account: Option<AccountResponseWithRelations>,
    pub currency: CurrencyResponse,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BudgetCreate {
    #[serde(flatten)]
    pub core: BudgetBase,
    pub currency: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BudgetUpdate {
    pub account_serial_num: Option<String>,
    pub name: Option<String>,
    pub description: Option<String>,
    pub category: Option<String>,
    pub amount: Option<Decimal>,
    pub currency: Option<String>,
    pub repeat_period_type: Option<String>,
    pub repeat_period: Option<String>,
    pub start_date: Option<DateTime<FixedOffset>>,
    pub end_date: Option<DateTime<FixedOffset>>,
    pub used_amount: Option<Decimal>,
    pub is_active: Option<bool>,
    pub alert_enabled: Option<bool>,
    pub alert_threshold: Option<String>,
    pub color: Option<String>,
    pub current_period_used: Option<Decimal>,
    pub current_period_start: Option<NaiveDate>,
    pub budget_type: Option<String>,
    pub progress: Option<Decimal>,
    pub linked_goal: Option<String>,
    pub reminders: Option<serde_json::Value>,
    pub priority: Option<i8>,
    pub tags: Option<serde_json::Value>,
    pub auto_rollover: Option<bool>,
    pub rollover_history: Option<serde_json::Value>,
    pub sharing_settings: Option<serde_json::Value>,
    pub attachments: Option<serde_json::Value>,
    pub budget_scope_type: Option<String>,
    pub account_scope: Option<serde_json::Value>,
    pub category_scope: Option<serde_json::Value>,
    pub advanced_rules: Option<serde_json::Value>,
}

impl BudgetUpdate {
    pub fn apply_to_model(self, model: &mut entity::budget::ActiveModel) {
        // Update fields if they have new values
        if let Some(account_serial_num) = self.account_serial_num {
            model.account_serial_num = ActiveValue::Set(Some(account_serial_num));
        }
        if let Some(name) = self.name {
            model.name = ActiveValue::Set(name);
        }
        if let Some(amount) = self.amount {
            model.amount = ActiveValue::Set(amount);
        }
        if let Some(currency) = self.currency {
            model.currency = ActiveValue::Set(currency);
        }
        if let Some(repeat_period) = self.repeat_period {
            model.repeat_period = ActiveValue::Set(parse_json_field(
                &repeat_period,
                "repeat_period",
                serde_json::Value::Null,
            ));
        }
        if let Some(start_date) = self.start_date {
            model.start_date = ActiveValue::Set(start_date);
        }
        if let Some(end_date) = self.end_date {
            model.end_date = ActiveValue::Set(end_date);
        }
        if let Some(used_amount) = self.used_amount {
            model.used_amount = ActiveValue::Set(used_amount);
        }
        if let Some(is_active) = self.is_active {
            model.is_active = ActiveValue::Set(is_active);
        }
        if let Some(alert_enabled) = self.alert_enabled {
            model.alert_enabled = ActiveValue::Set(alert_enabled);
        }
        if let Some(alert_threshold) = self.alert_threshold {
            model.alert_threshold = ActiveValue::Set(parse_json_field(
                &alert_threshold,
                "alert_threshold",
                Some(serde_json::Value::Null),
            ));
        }
        if let Some(color) = self.color {
            model.color = ActiveValue::Set(Some(color));
        }

        if let Some(current_period_used) = self.current_period_used {
            model.current_period_used = ActiveValue::Set(current_period_used);
        }
        if let Some(current_period_start) = self.current_period_start {
            model.current_period_start = ActiveValue::Set(current_period_start);
        }
        if let Some(budget_type) = self.budget_type {
            model.budget_type = ActiveValue::Set(budget_type);
        }
        if let Some(progress) = self.progress {
            model.progress = ActiveValue::Set(progress);
        }
        if let Some(linked_goal) = self.linked_goal {
            model.linked_goal = ActiveValue::Set(Some(linked_goal));
        }
        if let Some(reminders) = self.reminders {
            model.reminders = ActiveValue::Set(Some(reminders));
        }
        if let Some(priority) = self.priority {
            model.priority = ActiveValue::Set(priority);
        }
        if let Some(tags) = self.tags {
            model.tags = ActiveValue::Set(Some(tags));
        }
        if let Some(auto_rollover) = self.auto_rollover {
            model.auto_rollover = ActiveValue::Set(auto_rollover);
        }
        if let Some(rollover_history) = self.rollover_history {
            model.rollover_history = ActiveValue::Set(Some(rollover_history));
        }
        if let Some(sharing_settings) = self.sharing_settings {
            model.sharing_settings = ActiveValue::Set(Some(sharing_settings));
        }
        if let Some(attachments) = self.attachments {
            model.attachments = ActiveValue::Set(Some(attachments));
        }
        if let Some(budget_scope_type) = self.budget_scope_type {
            model.budget_scope_type = ActiveValue::Set(budget_scope_type);
        }
        if let Some(account_scope) = self.account_scope {
            model.account_scope = ActiveValue::Set(Some(account_scope));
        }
        if let Some(category_scope) = self.category_scope {
            model.category_scope = ActiveValue::Set(Some(category_scope));
        }
        if let Some(advanced_rules) = self.advanced_rules {
            model.advanced_rules = ActiveValue::Set(Some(advanced_rules));
        }
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()))
    }
}

impl TryFrom<BudgetCreate> for entity::budget::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: BudgetCreate) -> Result<Self, Self::Error> {
        value.validate()?;
        let serial_num = McgUuid::uuid(38);
        let budget = value.core;
        let now = DateUtils::local_now();
        Ok(entity::budget::ActiveModel {
            serial_num: ActiveValue::Set(serial_num),
            account_serial_num: ActiveValue::Set(budget.account_serial_num),
            name: ActiveValue::Set(budget.name),
            description: ActiveValue::Set(budget.description),
            amount: ActiveValue::Set(budget.amount),
            used_amount: ActiveValue::Set(budget.used_amount),
            currency: ActiveValue::Set(value.currency),
            repeat_period_type: ActiveValue::Set(budget.repeat_period_type),
            repeat_period: ActiveValue::Set(budget.repeat_period),
            start_date: ActiveValue::Set(budget.start_date),
            end_date: ActiveValue::Set(budget.end_date),
            is_active: ActiveValue::Set(budget.is_active),
            alert_enabled: ActiveValue::Set(budget.alert_enabled),
            alert_threshold: ActiveValue::Set(budget.alert_threshold),
            color: ActiveValue::Set(budget.color),
            current_period_used: ActiveValue::Set(Decimal::ZERO),
            current_period_start: ActiveValue::Set(DateUtils::local_now_naivedate()),
            last_reset_at: ActiveValue::Set(now),
            budget_type: ActiveValue::Set("Standard".to_string()),
            progress: ActiveValue::Set(Decimal::ZERO),
            linked_goal: ActiveValue::Set(None),
            reminders: ActiveValue::Set(None),
            priority: ActiveValue::Set(0),
            tags: ActiveValue::Set(None),
            auto_rollover: ActiveValue::Set(false),
            rollover_history: ActiveValue::Set(None),
            sharing_settings: ActiveValue::Set(None),
            attachments: ActiveValue::Set(None),
            budget_scope_type: ActiveValue::Set(budget.budget_scope_type),
            account_scope: ActiveValue::Set(budget.account_scope),
            category_scope: ActiveValue::Set(budget.category_scope),
            advanced_rules: ActiveValue::Set(budget.advanced_rules),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<BudgetUpdate> for entity::budget::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: BudgetUpdate) -> Result<Self, Self::Error> {
        value.validate()?;
        let now = DateUtils::local_now();
        Ok(entity::budget::ActiveModel {
            serial_num: ActiveValue::NotSet,
            name: value.name.map_or(ActiveValue::NotSet, ActiveValue::Set),
            description: value
                .description
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            account_serial_num: value
                .account_serial_num
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            amount: value.amount.map_or(ActiveValue::NotSet, ActiveValue::Set),
            used_amount: value
                .used_amount
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            currency: value.currency.map_or(ActiveValue::NotSet, ActiveValue::Set),
            repeat_period_type: value
                .repeat_period_type
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            repeat_period: value.repeat_period.map_or(ActiveValue::NotSet, |val| {
                ActiveValue::Set(parse_json_field(
                    &val,
                    "repeat_period",
                    serde_json::Value::Null,
                ))
            }),
            start_date: value
                .start_date
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            end_date: value.end_date.map_or(ActiveValue::NotSet, ActiveValue::Set),
            is_active: value
                .is_active
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            alert_enabled: value
                .alert_enabled
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            alert_threshold: value.alert_threshold.map_or(ActiveValue::NotSet, |val| {
                ActiveValue::Set(parse_json_field(
                    &val,
                    "alert_threshold",
                    Some(serde_json::Value::Null),
                ))
            }),
            color: value
                .color
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            current_period_used: ActiveValue::Set(Decimal::ZERO),
            current_period_start: ActiveValue::Set(DateUtils::local_now_naivedate()),
            last_reset_at: ActiveValue::Set(now),
            budget_type: ActiveValue::Set("Standard".to_string()),
            progress: ActiveValue::Set(Decimal::ZERO),
            linked_goal: ActiveValue::Set(None),
            reminders: ActiveValue::Set(None),
            priority: ActiveValue::Set(0),
            tags: ActiveValue::Set(None),
            auto_rollover: ActiveValue::Set(false),
            rollover_history: ActiveValue::Set(None),
            sharing_settings: ActiveValue::Set(None),
            attachments: ActiveValue::Set(None),
            budget_scope_type: value
                .budget_scope_type
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            account_scope: value
                .account_scope
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            category_scope: value
                .category_scope
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            advanced_rules: value
                .advanced_rules
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl From<BudgetWithAccount> for Budget {
    fn from(value: BudgetWithAccount) -> Self {
        let budget = value.budget;
        let account = value.account.map(AccountResponseWithRelations::from);
        let cny = value.currency;
        Self {
            serial_num: budget.serial_num,
            core: BudgetBase {
                name: budget.name,
                description: budget.description,
                account_serial_num: budget.account_serial_num,
                amount: budget.amount,
                used_amount: budget.used_amount,
                repeat_period_type: budget.repeat_period_type,
                repeat_period: budget.repeat_period,
                start_date: budget.start_date,
                end_date: budget.end_date,
                is_active: budget.is_active,
                alert_enabled: budget.alert_enabled,
                alert_threshold: budget.alert_threshold,
                color: budget.color,
                current_period_used: budget.current_period_used,
                current_period_start: budget.current_period_start,
                budget_type: budget.budget_type,
                progress: budget.progress,
                linked_goal: budget.linked_goal,
                reminders: budget.reminders,
                priority: budget.priority,
                tags: budget.tags,
                auto_rollover: budget.auto_rollover,
                rollover_history: budget.rollover_history,
                sharing_settings: budget.sharing_settings,
                attachments: budget.attachments,
                budget_scope_type: budget.budget_scope_type,
                account_scope: budget.account_scope,
                category_scope: budget.category_scope,
                advanced_rules: budget.advanced_rules,
            },
            account,
            currency: CurrencyResponse::from(cny),
            created_at: budget.created_at,
            updated_at: budget.updated_at,
        }
    }
}
