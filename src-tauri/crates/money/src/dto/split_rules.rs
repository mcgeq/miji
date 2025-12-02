use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use common::paginations::Filter;
use sea_orm::prelude::Decimal;
use sea_orm::{ActiveValue::{self, Set}, Condition};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use validator::Validate;

/// 分摊规则响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRuleResponse {
    pub serial_num: String,
    pub family_ledger_serial_num: String,
    pub name: String,
    pub description: Option<String>,
    pub rule_type: String,
    pub rule_config: JsonValue,
    pub participant_members: JsonValue,
    pub is_template: bool,
    pub is_default: bool,
    pub category: Option<String>,
    pub sub_category: Option<String>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
    pub tags: Option<JsonValue>,
    pub priority: i32,
    pub is_active: bool,
    pub created_by: String,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

impl From<entity::split_rules::Model> for SplitRuleResponse {
    fn from(model: entity::split_rules::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            family_ledger_serial_num: model.family_ledger_serial_num,
            name: model.name,
            description: model.description,
            rule_type: model.rule_type,
            rule_config: model.rule_config,
            participant_members: model.participant_members,
            is_template: model.is_template,
            is_default: model.is_default,
            category: model.category,
            sub_category: model.sub_category,
            min_amount: model.min_amount,
            max_amount: model.max_amount,
            tags: model.tags,
            priority: model.priority,
            is_active: model.is_active,
            created_by: model.created_by,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

/// 创建分摊规则请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SplitRuleCreate {
    #[validate(length(min = 1, max = 100, message = "规则名称长度必须在1-100字符之间"))]
    pub name: String,
    
    #[validate(length(max = 500, message = "描述长度不能超过500字符"))]
    pub description: Option<String>,
    
    #[validate(length(min = 1, message = "规则类型不能为空"))]
    pub rule_type: String,
    
    pub rule_config: JsonValue,
    pub participant_members: JsonValue,
    pub is_template: Option<bool>,
    pub is_default: Option<bool>,
    pub category: Option<String>,
    pub sub_category: Option<String>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
    pub tags: Option<JsonValue>,
    pub priority: Option<i32>,
    pub is_active: Option<bool>,
}

/// 更新分摊规则请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct SplitRuleUpdate {
    #[validate(length(min = 1, max = 100, message = "规则名称长度必须在1-100字符之间"))]
    pub name: Option<String>,
    
    #[validate(length(max = 500, message = "描述长度不能超过500字符"))]
    pub description: Option<String>,
    
    pub rule_type: Option<String>,
    pub rule_config: Option<JsonValue>,
    pub participant_members: Option<JsonValue>,
    pub is_template: Option<bool>,
    pub is_default: Option<bool>,
    pub category: Option<String>,
    pub sub_category: Option<String>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
    pub tags: Option<JsonValue>,
    pub priority: Option<i32>,
    pub is_active: Option<bool>,
}

impl TryFrom<SplitRuleCreate> for entity::split_rules::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(request: SplitRuleCreate) -> Result<Self, Self::Error> {
        request.validate()?;
        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38);

        Ok(entity::split_rules::ActiveModel {
            serial_num: Set(serial_num),
            family_ledger_serial_num: ActiveValue::NotSet, // 需要在服务层设置
            name: Set(request.name),
            description: Set(request.description),
            rule_type: Set(request.rule_type),
            rule_config: Set(request.rule_config),
            participant_members: Set(request.participant_members),
            is_template: Set(request.is_template.unwrap_or(false)),
            is_default: Set(request.is_default.unwrap_or(false)),
            category: Set(request.category),
            sub_category: Set(request.sub_category),
            min_amount: Set(request.min_amount),
            max_amount: Set(request.max_amount),
            tags: Set(request.tags),
            priority: Set(request.priority.unwrap_or(0)),
            is_active: Set(request.is_active.unwrap_or(true)),
            created_by: ActiveValue::NotSet, // 需要在服务层设置
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl SplitRuleUpdate {
    pub fn apply_to_model(self, model: &mut entity::split_rules::ActiveModel) {
        let now = DateUtils::local_now();

        if let Some(name) = self.name {
            model.name = Set(name);
        }
        if let Some(description) = self.description {
            model.description = Set(Some(description));
        }
        if let Some(rule_type) = self.rule_type {
            model.rule_type = Set(rule_type);
        }
        if let Some(rule_config) = self.rule_config {
            model.rule_config = Set(rule_config);
        }
        if let Some(participant_members) = self.participant_members {
            model.participant_members = Set(participant_members);
        }
        if let Some(is_template) = self.is_template {
            model.is_template = Set(is_template);
        }
        if let Some(is_default) = self.is_default {
            model.is_default = Set(is_default);
        }
        if let Some(category) = self.category {
            model.category = Set(Some(category));
        }
        if let Some(sub_category) = self.sub_category {
            model.sub_category = Set(Some(sub_category));
        }
        if let Some(min_amount) = self.min_amount {
            model.min_amount = Set(Some(min_amount));
        }
        if let Some(max_amount) = self.max_amount {
            model.max_amount = Set(Some(max_amount));
        }
        if let Some(tags) = self.tags {
            model.tags = Set(Some(tags));
        }
        if let Some(priority) = self.priority {
            model.priority = Set(priority);
        }
        if let Some(is_active) = self.is_active {
            model.is_active = Set(is_active);
        }

        model.updated_at = Set(Some(now));
    }
}

/// 分摊规则配置结构
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRuleConfig {
    pub rule_type: String,
    pub participants: Vec<SplitParticipant>,
}

/// 分摊参与者
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitParticipant {
    pub member_serial_num: String,
    pub member_name: String,
    pub percentage: Option<Decimal>,
    pub fixed_amount: Option<Decimal>,
    pub weight: Option<i32>,
}

/// 分摊规则查询参数
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SplitRuleQuery {
    pub family_ledger_serial_num: Option<String>,
    pub rule_type: Option<String>,
    pub is_template: Option<bool>,
    pub is_active: Option<bool>,
    pub category: Option<String>,
    pub page: Option<u64>,
    pub page_size: Option<u64>,
}

// Filter trait 实现
impl Filter<entity::split_rules::Entity> for SplitRuleCreate {
    fn to_condition(&self) -> Condition {
        Condition::all() // 创建 DTO 不需要过滤条件
    }
}
