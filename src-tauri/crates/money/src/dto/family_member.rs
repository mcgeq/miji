use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use sea_orm::{ActiveValue::{self, Set}, prelude::Decimal};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyMemberResponse {
    pub serial_num: String,
    pub name: String,
    pub role: String,
    pub is_primary: bool,
    pub permissions: String,
    // 新增字段
    pub user_id: Option<String>,
    pub avatar_url: Option<String>,
    pub color: Option<String>,
    pub total_paid: Decimal,
    pub total_owed: Decimal,
    pub balance: Decimal,
    pub status: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

impl From<entity::family_member::Model> for FamilyMemberResponse {
    fn from(model: entity::family_member::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            name: model.name,
            role: model.role,
            is_primary: model.is_primary,
            permissions: model.permissions,
            user_id: model.user_id,
            avatar_url: model.avatar_url,
            color: model.color,
            total_paid: model.total_paid,
            total_owed: model.total_owed,
            balance: model.balance,
            status: model.status,
            email: model.email,
            phone: model.phone,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

impl From<&entity::family_member::Model> for FamilyMemberResponse {
    fn from(model: &entity::family_member::Model) -> Self {
        Self {
            serial_num: model.serial_num.clone(),
            name: model.name.clone(),
            role: model.role.clone(),
            is_primary: model.is_primary,
            permissions: model.permissions.clone(),
            user_id: model.user_id.clone(),
            avatar_url: model.avatar_url.clone(),
            color: model.color.clone(),
            total_paid: model.total_paid,
            total_owed: model.total_owed,
            balance: model.balance,
            status: model.status.clone(),
            email: model.email.clone(),
            phone: model.phone.clone(),
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct FamilyMemberCreate {
    #[validate(length(min = 1, max = 100, message = "名称长度必须在1-100字符之间"))]
    pub name: String,

    #[validate(length(min = 1, max = 50, message = "角色长度必须在1-50字符之间"))]
    pub role: String,
    pub is_primary: bool,

    #[validate(length(min = 1, max = 1000, message = "权限字符串长度必须在1-1000字符之间"))]
    pub permissions: String,
    
    // 新增字段
    pub user_id: Option<String>,
    pub avatar_url: Option<String>,
    pub color: Option<String>,
    pub status: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

/// 更新家庭成员请求 DTO
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyMemberSearchQuery {
    pub keyword: Option<String>, // 关键词搜索，支持姓名、邮箱模糊匹配
    pub name: Option<String>,    // 按姓名搜索
    pub email: Option<String>,   // 按邮箱搜索
    pub status: Option<String>,  // 按状态过滤
    pub role: Option<String>,    // 按角色过滤
    pub user_id: Option<String>, // 按关联用户ID过滤
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyMemberSearchResponse {
    pub members: Vec<FamilyMemberResponse>,
    pub total: u64,
    pub has_more: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct FamilyMemberUpdate {
    pub name: Option<String>,

    pub role: Option<String>,

    pub is_primary: Option<bool>,

    pub permissions: Option<String>,
    
    // 新增字段
    pub user_id: Option<String>,
    pub avatar_url: Option<String>,
    pub color: Option<String>,
    pub status: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

impl TryFrom<FamilyMemberCreate> for entity::family_member::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(request: FamilyMemberCreate) -> Result<Self, Self::Error> {
        request.validate()?;
        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38); // 假设使用与 Account 相同的 UUID 生成逻辑

        Ok(entity::family_member::ActiveModel {
            serial_num: Set(serial_num),
            name: Set(request.name),
            role: Set(request.role),
            is_primary: Set(request.is_primary),
            permissions: Set(request.permissions),
            // 新增字段
            user_id: Set(request.user_id),
            avatar_url: Set(request.avatar_url),
            color: Set(request.color),
            total_paid: Set(Decimal::ZERO),
            total_owed: Set(Decimal::ZERO),
            balance: Set(Decimal::ZERO),
            status: Set(request.status.unwrap_or_else(|| "Active".to_string())),
            email: Set(request.email),
            phone: Set(request.phone),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl TryFrom<FamilyMemberUpdate> for entity::family_member::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: FamilyMemberUpdate) -> Result<Self, Self::Error> {
        value.validate()?;
        let now = DateUtils::local_now();
        Ok(entity::family_member::ActiveModel {
            serial_num: ActiveValue::NotSet,
            name: value.name.map_or(ActiveValue::NotSet, ActiveValue::Set),
            role: value.role.map_or(ActiveValue::NotSet, ActiveValue::Set),
            is_primary: value
                .is_primary
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            permissions: value
                .permissions
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            // 新增字段
            user_id: value.user_id.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            avatar_url: value.avatar_url.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            color: value.color.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            total_paid: ActiveValue::NotSet, // 统计字段不在更新中修改
            total_owed: ActiveValue::NotSet,
            balance: ActiveValue::NotSet,
            status: value.status.map_or(ActiveValue::NotSet, ActiveValue::Set),
            email: value.email.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            phone: value.phone.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl FamilyMemberUpdate {
    pub fn apply_to_model(self, model: &mut entity::family_member::ActiveModel) {
        let now = DateUtils::local_now();

        if let Some(name) = self.name {
            model.name = Set(name);
        }
        if let Some(role) = self.role {
            model.role = Set(role);
        }
        if let Some(is_primary) = self.is_primary {
            model.is_primary = Set(is_primary);
        }
        if let Some(permissions) = self.permissions {
            model.permissions = Set(permissions);
        }
        
        // 新增字段
        if let Some(user_id) = self.user_id {
            model.user_id = Set(Some(user_id));
        }
        if let Some(avatar_url) = self.avatar_url {
            model.avatar_url = Set(Some(avatar_url));
        }
        if let Some(color) = self.color {
            model.color = Set(Some(color));
        }
        if let Some(status) = self.status {
            model.status = Set(status);
        }
        if let Some(email) = self.email {
            model.email = Set(Some(email));
        }
        if let Some(phone) = self.phone {
            model.phone = Set(Some(phone));
        }

        // 更新 updated_at 字段
        model.updated_at = Set(Some(now));
    }
}
