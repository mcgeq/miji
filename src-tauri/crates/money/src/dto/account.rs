use chrono::{DateTime, Utc};
use common::utils::uuid::McgUuid;
use entity::{account, currency};
use sea_orm::{ActiveValue::Set, prelude::Decimal};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Deserialize, Validate)]
pub struct CreateAccountDto {
    #[validate(length(min = 1, max = 100, message = "账户名称长度必须在1-100字符之间"))]
    pub name: String,

    #[validate(length(max = 1000, message = "描述长度不能超过1000字符"))]
    pub description: String,

    #[validate(length(min = 1, max = 50, message = "账户类型长度必须在1-50字符之间"))]
    pub r#type: String,

    #[validate(range(min = 0.00, message = "初始余额不能为负数"))]
    pub initial_balance: Decimal,

    #[validate(length(min = 3, max = 3, message = "货币代码必须是3个字符"))]
    pub currency: String,

    #[validate(required(message = "是否共享必须指定"))]
    pub is_shared: Option<bool>,

    #[validate(length(max = 100, message = "所有者ID长度不能超过100字符"))]
    pub owner_id: Option<String>,

    #[validate(length(max = 20, message = "颜色代码长度不能超过20字符"))]
    pub color: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Validate)]
pub struct UpdateAccountDto {
    #[validate(length(min = 1, max = 100, message = "账户名称长度必须在1-100字符之间"))]
    pub name: Option<String>,

    #[validate(length(max = 1000, message = "描述长度不能超过1000字符"))]
    pub description: Option<String>,

    #[validate(length(min = 1, max = 50, message = "账户类型长度必须在1-50字符之间"))]
    pub r#type: Option<String>,

    #[validate(length(min = 3, max = 3, message = "货币代码必须是3个字符"))]
    pub currency: Option<String>,

    pub is_shared: Option<bool>,

    #[validate(length(max = 100, message = "所有者ID长度不能超过100字符"))]
    pub owner_id: Option<String>,

    #[validate(length(max = 20, message = "颜色代码长度不能超过20字符"))]
    pub color: Option<String>,

    pub is_active: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AccountResponseDto {
    pub serial_num: String,
    pub name: String,
    pub description: String,
    pub r#type: String,
    pub balance: Decimal,
    pub initial_balance: Decimal,
    pub currency: currency::Model,
    pub is_shared: bool,
    pub owner_id: Option<String>,
    pub color: Option<String>,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,
}

impl From<(account::Model, currency::Model)> for AccountResponseDto {
    fn from((account, currency): (account::Model, currency::Model)) -> Self {
        AccountResponseDto {
            serial_num: account.serial_num,
            name: account.name,
            description: account.description,
            r#type: account.r#type,
            balance: account.balance,
            initial_balance: account.initial_balance,
            currency, // 直接使用完整的 Currency 实体
            is_shared: account.is_shared != 0,
            owner_id: account.owner_id,
            color: account.color,
            is_active: account.is_active != 0,
            created_at: DateTime::parse_from_rfc3339(&account.created_at)
                .expect("Invalid created_at format")
                .with_timezone(&Utc),
            updated_at: account.updated_at.as_ref().map(|dt| {
                DateTime::parse_from_rfc3339(dt)
                    .expect("Invalid updated_at format")
                    .with_timezone(&Utc)
            }),
        }
    }
}

impl TryFrom<CreateAccountDto> for account::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(dto: CreateAccountDto) -> Result<Self, Self::Error> {
        // 验证 DTO
        dto.validate()?;
        // 生成唯一序列号
        let serial_num = McgUuid::uuid(38);

        // 获取当前时间
        let now = Utc::now().to_rfc3339();

        Ok(account::ActiveModel {
            serial_num: Set(serial_num),
            name: Set(dto.name),
            description: Set(dto.description),
            r#type: Set(dto.r#type),
            balance: Set(dto.initial_balance.clone()),
            initial_balance: Set(dto.initial_balance),
            currency: Set(dto.currency),
            is_shared: Set(dto.is_shared.unwrap_or(false) as i32),
            owner_id: Set(dto.owner_id),
            color: Set(dto.color),
            is_active: Set(1), // 默认激活
            created_at: Set(now),
            updated_at: Set(None),
        })
    }
}

impl TryFrom<UpdateAccountDto> for account::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(dto: UpdateAccountDto) -> Result<Self, Self::Error> {
        // 验证 DTO
        dto.validate()?;

        // 获取当前时间
        let now = Some(Utc::now().to_rfc3339());

        let mut active_model = account::ActiveModel::default();

        // 设置更新的字段
        if let Some(name) = dto.name {
            active_model.name = Set(name);
        }
        if let Some(description) = dto.description {
            active_model.description = Set(description);
        }
        if let Some(r#type) = dto.r#type {
            active_model.r#type = Set(r#type);
        }
        if let Some(currency) = dto.currency {
            active_model.currency = Set(currency);
        }
        if let Some(is_shared) = dto.is_shared {
            active_model.is_shared = Set(is_shared as i32);
        }
        if let Some(owner_id) = dto.owner_id {
            active_model.owner_id = Set(Some(owner_id));
        }
        if let Some(color) = dto.color {
            active_model.color = Set(Some(color));
        }
        if let Some(is_active) = dto.is_active {
            active_model.is_active = Set(is_active as i32);
        }

        // 设置更新时间
        active_model.updated_at = Set(now);

        Ok(active_model)
    }
}
