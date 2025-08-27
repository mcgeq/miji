use common::{
    paginations::PagedResult,
    utils::{date::DateUtils, uuid::McgUuid},
};
use entity::account;
use sea_orm::{prelude::Decimal, ActiveValue::Set, FromQueryResult};
use serde::{Deserialize, Serialize};
use validator::{Validate, ValidationError};

use crate::services::account::AccountWithRelations;

#[derive(Debug, Clone, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct CreateAccountRequest {
    #[validate(length(min = 1, max = 100, message = "账户名称长度必须在1-100字符之间"))]
    pub name: String,

    #[validate(length(max = 1000, message = "描述长度不能超过1000字符"))]
    pub description: String,

    #[validate(length(min = 1, max = 50, message = "账户类型长度必须在1-50字符之间"))]
    pub r#type: String,

    #[validate(custom(function = "validate_non_negative_amount", message = "金额必须非负数"))]
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
pub struct UpdateAccountRequest {
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

/// 资产汇总统计结果
#[derive(Debug, Deserialize, Serialize, FromQueryResult)]
pub struct AccountBalanceSummary {
    pub bank_savings_balance: Decimal,     // 银行/储蓄余额
    pub cash_balance: Decimal,             // 现金余额
    pub credit_card_balance: Decimal,      // 信用卡余额（绝对值）
    pub investment_balance: Decimal,       // 投资余额
    pub alipay_balance: Decimal,           // 支付宝余额
    pub wechat_balance: Decimal,           // 微信余额
    pub cloud_quick_pass_balance: Decimal, // 云闪付余额
    pub other_balance: Decimal,            // 其他余额
    pub total_balance: Decimal,            // 总余额
    pub adjusted_net_worth: Decimal,       // 调整后净资产（信用卡负向计算）
    pub total_assets: Decimal,             // 总资产（不含信用卡）
}

impl Default for AccountBalanceSummary {
    fn default() -> Self {
        Self {
            bank_savings_balance: Decimal::ZERO,
            cash_balance: Decimal::ZERO,
            credit_card_balance: Decimal::ZERO,
            investment_balance: Decimal::ZERO,
            alipay_balance: Decimal::ZERO,
            wechat_balance: Decimal::ZERO,
            cloud_quick_pass_balance: Decimal::ZERO,
            other_balance: Decimal::ZERO,
            total_balance: Decimal::ZERO,
            adjusted_net_worth: Decimal::ZERO,
            total_assets: Decimal::ZERO,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AccountResponse {
    pub serial_num: String,
    pub name: String,
    pub description: String,
    pub r#type: String,
    pub balance: Decimal,
    pub initial_balance: Decimal,
    pub currency: CurrencyInfo,
    pub is_shared: bool,
    pub owner_id: Option<String>,
    pub color: Option<String>,
    pub is_active: bool,
    pub created_at: String,
    pub updated_at: Option<String>,
}

/// 包含完整关联信息的账户响应
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AccountResponseWithRelations {
    pub serial_num: String,
    pub name: String,
    pub description: String,
    pub r#type: String,
    pub balance: Decimal,
    pub initial_balance: Decimal,
    pub currency: CurrencyInfo,
    pub is_shared: bool,
    pub owner_id: Option<String>,
    pub owner: Option<OwnerInfo>,
    pub color: Option<String>,
    pub is_active: bool,
    pub created_at: String,
    pub updated_at: Option<String>,
}

/// 货币信息
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CurrencyInfo {
    pub code: String,
    pub locale: String,
    pub symbol: String,
    pub created_at: String,
    pub updated_at: Option<String>,
}

/// 所有者信息
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct OwnerInfo {
    pub serial_num: String,
    pub name: String,
    pub role: Option<String>,
}

/// 实现从 (account, currency) 元组到 AccountResponse 的转换
impl From<(entity::account::Model, entity::currency::Model)> for AccountResponse {
    fn from((account, currency): (entity::account::Model, entity::currency::Model)) -> Self {
        Self {
            serial_num: account.serial_num,
            name: account.name,
            description: account.description,
            r#type: account.r#type,
            balance: account.balance,
            initial_balance: account.initial_balance,
            currency: CurrencyInfo::from(currency),
            is_shared: account.is_shared != 0,
            owner_id: account.owner_id,
            color: account.color,
            is_active: account.is_active != 0,
            created_at: account.created_at,
            updated_at: account.updated_at,
        }
    }
}

/// 实现从 AccountWithRelations 到 AccountResponseWithRelations 的转换
impl From<AccountWithRelations> for AccountResponseWithRelations {
    fn from(data: AccountWithRelations) -> Self {
        Self {
            serial_num: data.account.serial_num,
            name: data.account.name,
            description: data.account.description,
            r#type: data.account.r#type,
            balance: data.account.balance,
            initial_balance: data.account.initial_balance,
            currency: CurrencyInfo::from(data.currency),
            is_shared: data.account.is_shared != 0,
            owner_id: data.account.owner_id,
            owner: data.owner.map(OwnerInfo::from),
            color: data.account.color,
            is_active: data.account.is_active != 0,
            created_at: data.account.created_at,
            updated_at: data.account.updated_at,
        }
    }
}

/// 实现从 currency model 到 CurrencyInfo 的转换
impl From<entity::currency::Model> for CurrencyInfo {
    fn from(currency: entity::currency::Model) -> Self {
        Self {
            code: currency.code,
            locale: currency.locale,
            symbol: currency.symbol,
            created_at: currency.created_at,
            updated_at: currency.updated_at,
        }
    }
}

/// 实现从 family_member model 到 OwnerInfo 的转换
impl From<entity::family_member::Model> for OwnerInfo {
    fn from(member: entity::family_member::Model) -> Self {
        Self {
            serial_num: member.serial_num,
            name: member.name,
            role: Some(member.role),
        }
    }
}

impl TryFrom<CreateAccountRequest> for account::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(dto: CreateAccountRequest) -> Result<Self, Self::Error> {
        dto.validate()?;
        // 生成唯一序列号
        let serial_num = McgUuid::uuid(38);

        // 获取当前时间
        let now = DateUtils::local_rfc3339();

        Ok(account::ActiveModel {
            serial_num: Set(serial_num),
            name: Set(dto.name),
            description: Set(dto.description),
            r#type: Set(dto.r#type),
            balance: Set(dto.initial_balance),
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

impl TryFrom<UpdateAccountRequest> for account::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(request: UpdateAccountRequest) -> Result<Self, Self::Error> {
        // 验证 DTO
        request.validate()?;

        Ok(entity::account::ActiveModel {
            serial_num: sea_orm::ActiveValue::NotSet,
            name: request
                .name
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            description: request
                .description
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            r#type: request
                .r#type
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            balance: sea_orm::ActiveValue::NotSet, // 余额不能直接通过更新请求修改
            initial_balance: sea_orm::ActiveValue::NotSet,
            currency: request
                .currency
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            is_shared: request
                .is_shared
                .map_or(sea_orm::ActiveValue::NotSet, |val| {
                    sea_orm::ActiveValue::Set(val as i32)
                }),
            owner_id: match request.owner_id {
                Some(id) => sea_orm::ActiveValue::Set(Some(id)),
                None => sea_orm::ActiveValue::NotSet,
            },
            color: match request.color {
                Some(color) => sea_orm::ActiveValue::Set(Some(color)),
                None => sea_orm::ActiveValue::NotSet,
            },
            is_active: sea_orm::ActiveValue::NotSet,
            created_at: sea_orm::ActiveValue::NotSet,
            updated_at: sea_orm::ActiveValue::Set(Some(
                common::utils::date::DateUtils::local_rfc3339(),
            )),
        })
    }
}

fn validate_non_negative_amount(amount: &Decimal) -> Result<(), ValidationError> {
    if amount.is_sign_negative() {
        return Err(ValidationError::new("non_negative"));
    }
    Ok(())
}

pub fn convert_to_account(
    paged: PagedResult<(
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    )>,
) -> Vec<AccountResponseWithRelations> {
    paged
        .rows
        .into_iter()
        .map(|(account, currency, owner)| AccountResponseWithRelations {
            serial_num: account.serial_num,
            name: account.name,
            description: account.description,
            r#type: account.r#type,
            balance: account.balance,
            initial_balance: account.initial_balance,
            currency: CurrencyInfo {
                code: currency.code,
                locale: currency.locale,
                symbol: currency.symbol,
                created_at: currency.created_at,
                updated_at: currency.updated_at,
            },
            is_shared: account.is_shared != 0,
            owner_id: account.owner_id,
            owner: owner.map(|o| OwnerInfo {
                serial_num: o.serial_num,
                name: o.name,
                role: Some(o.role),
            }),
            color: account.color,
            is_active: account.is_active != 0,
            created_at: account.created_at,
            updated_at: account.updated_at,
        })
        .collect()
}

pub fn convert_to_response(
    paged: PagedResult<(
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    )>,
) -> PagedResult<AccountResponseWithRelations> {
    let rows = paged
        .rows
        .into_iter()
        .map(|(account, currency, owner)| AccountResponseWithRelations {
            serial_num: account.serial_num,
            name: account.name,
            description: account.description,
            r#type: account.r#type,
            balance: account.balance,
            initial_balance: account.initial_balance,
            currency: CurrencyInfo {
                code: currency.code,
                locale: currency.locale,
                symbol: currency.symbol,
                created_at: currency.created_at,
                updated_at: currency.updated_at,
            },
            is_shared: account.is_shared != 0,
            owner_id: account.owner_id,
            owner: owner.map(|o| OwnerInfo {
                serial_num: o.serial_num,
                name: o.name,
                role: Some(o.role),
            }),
            color: account.color,
            is_active: account.is_active != 0,
            created_at: account.created_at,
            updated_at: account.updated_at,
        })
        .collect();

    PagedResult {
        rows,
        total_count: paged.total_count,
        current_page: paged.current_page,
        page_size: paged.page_size,
        total_pages: paged.total_pages,
    }
}

// Helper function to convert tuple to AccountResponseWithRelations
pub fn tuple_to_response(
    (account, currency, owner): (
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    ),
) -> AccountResponseWithRelations {
    AccountResponseWithRelations {
        serial_num: account.serial_num,
        name: account.name,
        description: account.description,
        r#type: account.r#type,
        balance: account.balance,
        initial_balance: account.initial_balance,
        currency: CurrencyInfo {
            code: currency.code,
            locale: currency.locale,
            symbol: currency.symbol,
            created_at: currency.created_at,
            updated_at: currency.updated_at,
        },
        is_shared: account.is_shared != 0,
        owner_id: account.owner_id,
        owner: owner.map(|o| OwnerInfo {
            serial_num: o.serial_num,
            name: o.name,
            role: Some(o.role),
        }),
        color: account.color,
        is_active: account.is_active != 0,
        created_at: account.created_at,
        updated_at: account.updated_at,
    }
}
