use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use sea_orm::ActiveValue::{self, Set};
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
}

/// 更新家庭成员请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct FamilyMemberUpdate {
    #[validate(length(min = 1, max = 100, message = "名称长度必须在1-100字符之间"))]
    pub name: Option<String>,

    #[validate(length(min = 1, max = 50, message = "角色长度必须在1-50字符之间"))]
    pub role: Option<String>,

    pub is_primary: Option<bool>,

    #[validate(length(min = 1, max = 1000, message = "权限字符串长度必须在1-1000字符之间"))]
    pub permissions: Option<String>,
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

        // 更新 updated_at 字段
        model.updated_at = Set(Some(now));
    }
}
