use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use sea_orm::ActiveValue::Set;
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use validator::Validate;

// ======================
// 响应 DTO（API返回格式）
// ======================

/// 用户设置响应DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserSettingResponse {
    /// 设置ID
    pub serial_num: String,
    /// 用户ID
    pub user_serial_num: String,
    /// 设置键名
    pub setting_key: String,
    /// 设置值（JSON格式）
    pub setting_value: JsonValue,
    /// 值类型
    pub setting_type: String,
    /// 所属模块
    pub module: String,
    /// 设置描述
    pub description: Option<String>,
    /// 是否为默认值
    pub is_default: bool,
    /// 创建时间
    pub created_at: DateTime<FixedOffset>,
    /// 最后更新时间
    pub updated_at: DateTime<FixedOffset>,
}

impl From<entity::user_settings::Model> for UserSettingResponse {
    fn from(model: entity::user_settings::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            user_serial_num: model.user_serial_num,
            setting_key: model.setting_key,
            setting_value: model.setting_value,
            setting_type: model.setting_type,
            module: model.module,
            description: model.description,
            is_default: model.is_default,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

// ======================
// 创建请求 DTO
// ======================

/// 创建用户设置请求DTO
#[derive(Debug, Serialize, Deserialize, Validate, Clone)]
#[serde(rename_all = "camelCase")]
pub struct CreateUserSettingRequest {
    /// 用户ID
    #[validate(length(min = 1, message = "用户ID不能为空"))]
    pub user_serial_num: String,

    /// 设置键名（格式: settings.{module}.{field}）
    #[validate(
        length(min = 1, message = "设置键名不能为空"),
        custom(function = "validate_setting_key")
    )]
    pub setting_key: String,

    /// 设置值
    pub setting_value: JsonValue,

    /// 值类型
    #[validate(custom(function = "validate_setting_type"))]
    pub setting_type: String,

    /// 所属模块
    #[validate(custom(function = "validate_module"))]
    pub module: String,

    /// 设置描述
    pub description: Option<String>,

    /// 是否为默认值
    pub is_default: Option<bool>,
}

// ======================
// Tauri 命令 DTO（前端使用）
// ======================

/// 保存设置命令（前端调用）
#[derive(Debug, Serialize, Deserialize, Validate, Clone)]
#[serde(rename_all = "camelCase")]
pub struct SaveSettingCommand {
    /// 设置键名
    #[validate(custom(function = "validate_setting_key"))]
    pub key: String,

    /// 设置值（JSON格式）
    pub value: JsonValue,

    /// 值类型（string, number, boolean, object, array）
    #[validate(custom(function = "validate_setting_type"))]
    pub setting_type: String,

    /// 所属模块
    #[validate(custom(function = "validate_module"))]
    pub module: String,

    /// 设置描述（可选）
    pub description: Option<String>,
}

impl SaveSettingCommand {
    /// 转换为内部使用的 CreateUserSettingRequest
    pub fn to_create_request(self, user_serial_num: String) -> CreateUserSettingRequest {
        CreateUserSettingRequest {
            user_serial_num,
            setting_key: self.key,
            setting_value: self.value,
            setting_type: self.setting_type,
            module: self.module,
            description: self.description,
            is_default: Some(false),
        }
    }
}

// ======================
// 更新请求 DTO
// ======================

/// 更新用户设置请求DTO
#[derive(Debug, Serialize, Deserialize, Validate, Clone)]
#[serde(rename_all = "camelCase")]
pub struct UpdateUserSettingRequest {
    /// 设置值
    pub setting_value: Option<JsonValue>,

    /// 值类型
    #[validate(custom(function = "validate_setting_type"))]
    pub setting_type: Option<String>,

    /// 设置描述
    pub description: Option<String>,

    /// 是否为默认值
    pub is_default: Option<bool>,
}

impl UpdateUserSettingRequest {
    pub fn apply_to_model(&self, model: &mut entity::user_settings::ActiveModel) {
        if let Some(value) = &self.setting_value {
            model.setting_value = Set(value.clone());
        }
        if let Some(setting_type) = &self.setting_type {
            model.setting_type = Set(setting_type.clone());
        }
        if let Some(description) = &self.description {
            model.description = Set(Some(description.clone()));
        }
        if let Some(is_default) = self.is_default {
            model.is_default = Set(is_default);
        }
    }
}

// ======================
// 配置文件相关 DTO
// ======================

/// 用户设置配置文件响应DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserSettingProfileResponse {
    /// 配置ID
    pub serial_num: String,
    /// 用户ID
    pub user_serial_num: String,
    /// 配置名称
    pub profile_name: String,
    /// 配置数据
    pub profile_data: JsonValue,
    /// 是否激活
    pub is_active: bool,
    /// 是否默认
    pub is_default: bool,
    /// 配置描述
    pub description: Option<String>,
    /// 创建时间
    pub created_at: DateTime<FixedOffset>,
    /// 最后更新时间
    pub updated_at: DateTime<FixedOffset>,
}

impl From<entity::user_setting_profiles::Model> for UserSettingProfileResponse {
    fn from(model: entity::user_setting_profiles::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            user_serial_num: model.user_serial_num,
            profile_name: model.profile_name,
            profile_data: model.profile_data,
            is_active: model.is_active,
            is_default: model.is_default,
            description: model.description,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

/// 创建配置文件请求DTO
#[derive(Debug, Serialize, Deserialize, Validate, Clone)]
#[serde(rename_all = "camelCase")]
pub struct CreateUserSettingProfileRequest {
    /// 用户ID
    #[validate(length(min = 1, message = "用户ID不能为空"))]
    pub user_serial_num: String,

    /// 配置名称
    #[validate(length(min = 1, max = 50, message = "配置名称长度必须在1-50字符之间"))]
    pub profile_name: String,

    /// 配置数据
    pub profile_data: JsonValue,

    /// 配置描述
    pub description: Option<String>,
}

// ======================
// 历史记录相关 DTO
// ======================

/// 用户设置历史记录响应DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserSettingHistoryResponse {
    /// 历史记录ID
    pub serial_num: String,
    /// 用户ID
    pub user_serial_num: String,
    /// 设置键名
    pub setting_key: String,
    /// 旧值
    pub old_value: Option<JsonValue>,
    /// 新值
    pub new_value: JsonValue,
    /// 变更类型
    pub change_type: String,
    /// 变更来源
    pub changed_by: Option<String>,
    /// IP地址
    pub ip_address: Option<String>,
    /// User Agent
    pub user_agent: Option<String>,
    /// 变更时间
    pub created_at: DateTime<FixedOffset>,
}

impl From<entity::user_setting_history::Model> for UserSettingHistoryResponse {
    fn from(model: entity::user_setting_history::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            user_serial_num: model.user_serial_num,
            setting_key: model.setting_key,
            old_value: model.old_value,
            new_value: model.new_value,
            change_type: model.change_type,
            changed_by: model.changed_by,
            ip_address: model.ip_address,
            user_agent: model.user_agent,
            created_at: model.created_at,
        }
    }
}

// ======================
// From 实现
// ======================

/// CreateUserSettingRequest 直接转换为 ActiveModel
impl From<CreateUserSettingRequest> for entity::user_settings::ActiveModel {
    fn from(data: CreateUserSettingRequest) -> Self {
        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38);

        entity::user_settings::ActiveModel {
            serial_num: Set(serial_num),
            user_serial_num: Set(data.user_serial_num),
            setting_key: Set(data.setting_key),
            setting_value: Set(data.setting_value),
            setting_type: Set(data.setting_type),
            module: Set(data.module),
            description: Set(data.description),
            is_default: Set(data.is_default.unwrap_or(false)),
            created_at: Set(now.into()),
            updated_at: Set(now.into()),
        }
    }
}

/// CreateUserSettingProfileRequest 转换为 ActiveModel
impl From<CreateUserSettingProfileRequest> for entity::user_setting_profiles::ActiveModel {
    fn from(data: CreateUserSettingProfileRequest) -> Self {
        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38);

        entity::user_setting_profiles::ActiveModel {
            serial_num: Set(serial_num),
            user_serial_num: Set(data.user_serial_num),
            profile_name: Set(data.profile_name),
            profile_data: Set(data.profile_data),
            is_active: Set(false), // 新创建的配置默认不激活
            is_default: Set(false),
            description: Set(data.description),
            created_at: Set(now.into()),
            updated_at: Set(now.into()),
        }
    }
}

// ======================
// 验证函数
// ======================

/// 验证设置键名格式
fn validate_setting_key(key: &str) -> Result<(), validator::ValidationError> {
    if !key.starts_with("settings.") {
        return Err(validator::ValidationError::new(
            "设置键名必须以 'settings.' 开头",
        ));
    }
    Ok(())
}

/// 验证值类型
fn validate_setting_type(setting_type: &str) -> Result<(), validator::ValidationError> {
    const VALID_TYPES: &[&str] = &["string", "number", "boolean", "object", "array"];
    if !VALID_TYPES.contains(&setting_type) {
        return Err(validator::ValidationError::new(
            "值类型必须是: string, number, boolean, object, array 之一",
        ));
    }
    Ok(())
}

/// 验证模块名称
fn validate_module(module: &str) -> Result<(), validator::ValidationError> {
    const VALID_MODULES: &[&str] = &["general", "notification", "privacy", "security"];
    if !VALID_MODULES.contains(&module) {
        return Err(validator::ValidationError::new(
            "模块名称必须是: general, notification, privacy, security 之一",
        ));
    }
    Ok(())
}
