use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::set_active_value_t;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct ProjectBase {
    pub name: String,
    pub description: Option<String>,
    pub owner_id: Option<String>,
    pub color: Option<String>,
    pub is_archived: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct Project {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: ProjectBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct ProjectCreate {
    #[serde(flatten)]
    pub core: ProjectBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct ProjectUpdate {
    pub name: Option<String>,
    pub description: Option<Option<String>>,
    pub owner_id: Option<Option<String>>,
    pub color: Option<Option<String>>,
    pub is_archived: Option<bool>,
}

impl TryFrom<ProjectCreate> for entity::project::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: ProjectCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::project::ActiveModel {
            serial_num: ActiveValue::Set(McgUuid::uuid(38)),
            name: ActiveValue::Set(value.core.name),
            description: ActiveValue::Set(value.core.description),
            owner_id: ActiveValue::Set(value.core.owner_id),
            color: ActiveValue::Set(value.core.color),
            is_archived: ActiveValue::Set(value.core.is_archived),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<ProjectUpdate> for entity::project::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: ProjectUpdate) -> Result<Self, Self::Error> {
        Ok(entity::project::ActiveModel {
            serial_num: ActiveValue::NotSet,
            name: value.name.map_or(ActiveValue::NotSet, ActiveValue::Set),
            description: value
                .description
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            owner_id: value.owner_id.map_or(ActiveValue::NotSet, ActiveValue::Set),
            color: value.color.map_or(ActiveValue::NotSet, ActiveValue::Set),
            is_archived: value
                .is_archived
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl ProjectUpdate {
    pub fn apply_to_model(self, model: &mut entity::project::ActiveModel) {
        set_active_value_t!(model, self, name);
        set_active_value_t!(model, self, description);
        set_active_value_t!(model, self, owner_id);
        set_active_value_t!(model, self, color);
        set_active_value_t!(model, self, is_archived);
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
    }
}

impl From<entity::project::Model> for Project {
    fn from(value: entity::project::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: ProjectBase {
                name: value.name,
                description: value.description,
                owner_id: value.owner_id,
                color: value.color,
                is_archived: value.is_archived,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
