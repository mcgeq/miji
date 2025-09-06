use chrono::{DateTime, FixedOffset};
use common::{
    BusinessCode,
    error::AppError,
    utils::{date::DateUtils, uuid::McgUuid},
};
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Serialize, Deserialize)]
pub enum UserStatus {
    Active,
    Inactive,
    Suspended,
    Banned,
    Pending,
    Deleted,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum UserRole {
    Admin,
    User,
    Moderator,
    Editor,
    Guest,
    Developer,
    Owner,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum MemberUserRole {
    Owner,
    Admin,
    Member,
    Viewer,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserQuery {
    pub serial_num: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub name: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct User {
    pub serial_num: String,
    pub name: String,
    pub email: String,
    pub phone: Option<String>,
    pub avatar_url: Option<String>,
    pub last_login_at: Option<DateTime<FixedOffset>>,
    pub is_verified: bool,
    pub role: UserRole,
    pub status: UserStatus,
    pub email_verified_at: Option<DateTime<FixedOffset>>,
    pub phone_verified_at: Option<DateTime<FixedOffset>>,
    pub bio: Option<String>,
    pub language: Option<String>,
    pub timezone: Option<String>,
    pub last_active_at: Option<DateTime<FixedOffset>>,
    pub deleted_at: Option<DateTime<FixedOffset>>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct CreateUserDto {
    #[validate(length(min = 1, max = 100))]
    pub name: String,
    #[validate(email)]
    pub email: String,
    pub phone: Option<String>,
    #[validate(length(min = 8))]
    pub password: String,
    pub avatar_url: Option<String>,
    pub is_verified: bool,
    pub role: String,
    pub status: String,
    pub bio: Option<String>,
    pub language: Option<String>,
    pub timezone: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct UpdateUserDto {
    #[validate(length(min = 1, max = 100))]
    pub name: Option<String>,
    #[validate(email)]
    pub email: Option<String>,
    pub phone: Option<String>,
    #[validate(length(min = 8))]
    pub password: Option<String>,
    pub avatar_url: Option<String>,
    pub is_verified: Option<bool>,
    pub role: Option<String>,
    pub status: Option<String>,
    pub bio: Option<String>,
    pub language: Option<String>,
    pub timezone: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TokenResponse {
    pub token: String,
    pub expires_at: i64, // UNIX timestamp (seconds)
}

impl From<entity::users::Model> for User {
    fn from(model: entity::users::Model) -> Self {
        User {
            serial_num: model.serial_num,
            name: model.name,
            email: model.email,
            phone: model.phone,
            avatar_url: model.avatar_url,
            last_login_at: model.last_login_at,
            is_verified: model.is_verified,
            role: serde_json::from_str(&model.role).unwrap_or(UserRole::User),
            status: serde_json::from_str(&model.status).unwrap_or(UserStatus::Active),
            email_verified_at: model.email_verified_at,
            phone_verified_at: model.phone_verified_at,
            bio: model.bio,
            language: model.language,
            timezone: model.timezone,
            last_active_at: model.last_active_at,
            deleted_at: model.deleted_at,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

// 为 CreateUserDto 实现 TryFrom，转换为 ActiveModel
impl TryFrom<CreateUserDto> for entity::users::ActiveModel {
    type Error = AppError;

    fn try_from(data: CreateUserDto) -> Result<Self, Self::Error> {
        // 验证 DTO
        data.validate().map_err(AppError::from_validation_errors)?;
        // 验证 role 和 status
        if !is_valid_role(&data.role) {
            return Err(AppError::validation_failed(
                BusinessCode::ValidationError,
                "无效的角色值",
                None,
            ));
        }
        if !is_valid_status(&data.status) {
            return Err(AppError::validation_failed(
                BusinessCode::ValidationError,
                "无效的状态值",
                None,
            ));
        }
        let now = DateUtils::local_now();
        Ok(entity::users::ActiveModel {
            serial_num: ActiveValue::set(McgUuid::uuid(38)),
            name: ActiveValue::set(data.name),
            email: ActiveValue::set(data.email),
            phone: ActiveValue::set(data.phone),
            password: ActiveValue::set(data.password),
            avatar_url: ActiveValue::set(data.avatar_url),
            last_login_at: ActiveValue::set(None),
            is_verified: ActiveValue::set(data.is_verified),
            role: ActiveValue::set(data.role),
            status: ActiveValue::set(data.status),
            email_verified_at: ActiveValue::set(None),
            phone_verified_at: ActiveValue::set(None),
            bio: ActiveValue::set(data.bio),
            language: ActiveValue::set(data.language),
            timezone: ActiveValue::set(data.timezone),
            last_active_at: ActiveValue::set(None),
            deleted_at: ActiveValue::set(None),
            created_at: ActiveValue::set(now),
            updated_at: ActiveValue::set(Some(now)),
        })
    }
}

// 为 UpdateUserDto 实现 TryFrom，转换为 ActiveModel
impl TryFrom<UpdateUserDto> for entity::users::ActiveModel {
    type Error = AppError;

    fn try_from(data: UpdateUserDto) -> Result<Self, Self::Error> {
        // 验证 DTO
        data.validate().map_err(AppError::from_validation_errors)?;

        // 创建一个空的 ActiveModel，稍后通过 Model 填充
        let mut active_model = entity::users::ActiveModel {
            ..Default::default()
        };

        // 更新提供的字段
        if let Some(name) = data.name {
            active_model.name = ActiveValue::set(name);
        }
        if let Some(email) = data.email {
            active_model.email = ActiveValue::set(email);
        }
        if data.phone.is_some() {
            active_model.phone = ActiveValue::set(data.phone);
        }
        if let Some(password) = data.password {
            active_model.password = ActiveValue::set(password);
        }
        if data.avatar_url.is_some() {
            active_model.avatar_url = ActiveValue::set(data.avatar_url);
        }
        if let Some(is_verified) = data.is_verified {
            active_model.is_verified = ActiveValue::set(is_verified);
        }
        if let Some(role) = &data.role {
            if !is_valid_role(role) {
                return Err(AppError::validation_failed(
                    BusinessCode::ValidationError,
                    "无效的角色值",
                    None,
                ));
            }
            active_model.role = ActiveValue::set(role.clone());
        }
        if let Some(status) = &data.status {
            if !is_valid_status(status) {
                return Err(AppError::validation_failed(
                    BusinessCode::ValidationError,
                    "无效的状态值",
                    None,
                ));
            }
            active_model.status = ActiveValue::set(status.clone());
        }
        if data.bio.is_some() {
            active_model.bio = ActiveValue::set(data.bio);
        }
        if data.language.is_some() {
            active_model.language = ActiveValue::set(data.language);
        }
        if data.timezone.is_some() {
            active_model.timezone = ActiveValue::set(data.timezone);
        }
        active_model.updated_at = ActiveValue::set(Some(DateUtils::local_now()));

        Ok(active_model)
    }
}

// 辅助函数：验证 role 是否有效
fn is_valid_role(role: &str) -> bool {
    matches!(
        role.to_lowercase().as_str(),
        "admin" | "user" | "moderator" | "editor" | "guest" | "developer" | "owner"
    )
}

// 辅助函数：验证 status 是否有效
fn is_valid_status(status: &str) -> bool {
    matches!(
        status.to_lowercase().as_str(),
        "active" | "inactive" | "suspended" | "banned" | "pending" | "deleted"
    )
}
