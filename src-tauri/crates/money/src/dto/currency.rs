use chrono::{DateTime, FixedOffset};
use common::utils::date::DateUtils;
use lazy_static::lazy_static;
use regex::Regex;
use sea_orm::ActiveValue::Set;
use serde::{Deserialize, Serialize};
use validator::Validate;

lazy_static! {
    static ref ISO_4217_REGEX: Regex = Regex::new(r"^[A-Z]{3}$").unwrap();
}
// ======================
// 响应 DTO（API返回格式）
// ======================

/// 货币详情响应DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CurrencyResponse {
    /// ISO 货币代码 (USD, EUR等)
    pub code: String,
    /// 区域设置 (en-US, zh-CN等)
    pub locale: String,
    /// 货币符号 ($, €, ¥等)
    pub symbol: String,
    /// 是否为默认货币
    pub is_default: bool,
    /// 是否激活
    pub is_active: bool,
    /// 创建时间 (ISO 8601格式)
    pub created_at: DateTime<FixedOffset>,
    /// 最后更新时间 (ISO 8601格式)
    pub updated_at: Option<DateTime<FixedOffset>>,
}

// 实体模型到响应DTO的转换
impl From<entity::currency::Model> for CurrencyResponse {
    fn from(model: entity::currency::Model) -> Self {
        Self {
            code: model.code,
            locale: model.locale,
            symbol: model.symbol,
            is_default: model.is_default,
            is_active: model.is_active,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

// ======================
// 创建请求 DTO
// ======================

/// 创建货币请求DTO
#[derive(Debug, Serialize, Deserialize, Validate, Clone)]
#[serde(rename_all = "camelCase")]
pub struct CreateCurrencyRequest {
    #[validate(
        length(min = 3, max = 3, message = "货币代码必须是3个字符"),
        regex(
            path = *ISO_4217_REGEX,  // Reference the static regex
            message = "必须是ISO 4217标准大写字母代码"
        )
    )]
    pub code: String,

    #[validate(length(min = 2, max = 10, message = "区域格式长度需在2-10字符之间"))]
    pub locale: String,

    #[validate(length(min = 1, max = 5, message = "符号长度需在1-5字符之间"))]
    pub symbol: String,

    /// 是否为默认货币（可选，默认false）
    #[serde(default)]
    pub is_default: bool,

    /// 是否激活（可选，默认true）
    #[serde(default = "default_is_active")]
    pub is_active: bool,
}

fn default_is_active() -> bool {
    true
}

// 创建请求到实体模型的转换
impl From<CreateCurrencyRequest> for entity::currency::ActiveModel {
    fn from(request: CreateCurrencyRequest) -> Self {
        let now = DateUtils::local_now();

        entity::currency::ActiveModel {
            code: Set(request.code),
            locale: Set(request.locale),
            symbol: Set(request.symbol),
            is_default: Set(request.is_default),
            is_active: Set(request.is_active),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        }
    }
}

// ======================
// 更新请求 DTO
// ======================

/// 更新货币请求DTO
#[derive(Debug, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct UpdateCurrencyRequest {
    #[validate(
        length(min = 2, max = 10, message = "区域格式长度需在2-10字符之间"),
        custom(function = "validate_locale")  // 修复2: 使用正确的自定义验证语法
    )]
    pub locale: Option<String>,

    #[validate(length(min = 1, max = 5, message = "符号长度需在1-5字符之间"))]
    pub symbol: Option<String>,

    /// 是否为默认货币
    pub is_default: Option<bool>,

    /// 是否激活
    pub is_active: Option<bool>,
}

// 区域格式自定义验证
fn validate_locale(locale: &str) -> Result<(), validator::ValidationError> {
    if !locale.contains('-') {
        return Err(validator::ValidationError::new(
            "locale格式应为 language_REGION (如 en-US)",
        ));
    }
    Ok(())
}

// 更新请求应用到实体模型
impl UpdateCurrencyRequest {
    pub fn apply_to_model(self, model: &mut entity::currency::ActiveModel) {
        if let Some(locale) = self.locale {
            model.locale = Set(locale);
        }

        if let Some(symbol) = self.symbol {
            model.symbol = Set(symbol);
        }

        if let Some(is_default) = self.is_default {
            model.is_default = Set(is_default);
        }

        if let Some(is_active) = self.is_active {
            model.is_active = Set(is_active);
        }

        // 设置更新时间
        model.updated_at = Set(Some(DateUtils::local_now()));
    }
}

// ======================
// 查询参数 DTO
// ======================

/// 货币查询参数
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CurrencyQuery {
    /// 按货币代码过滤
    pub code: Option<String>,

    /// 按区域设置过滤
    pub locale: Option<String>,

    /// 按符号过滤
    pub symbol: Option<String>,

    /// 分页页码 (默认1)
    #[serde(default = "default_page")]
    pub page: u64,

    /// 每页数量 (默认20)
    #[serde(default = "default_page_size")]
    pub page_size: u64,
}

fn default_page() -> u64 {
    1
}
fn default_page_size() -> u64 {
    20
}
