use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::set_active_value_t;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TagBase {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct Tag {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: TagBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TagCreate {
    #[serde(flatten)]
    pub core: TagBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TagUpdate {
    pub name: Option<String>,
    pub description: Option<Option<String>>,
}

impl TryFrom<TagCreate> for entity::tag::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TagCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::tag::ActiveModel {
            serial_num: ActiveValue::Set(McgUuid::uuid(38)),
            name: ActiveValue::Set(value.core.name),
            description: ActiveValue::Set(value.core.description),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<TagUpdate> for entity::tag::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TagUpdate) -> Result<Self, Self::Error> {
        Ok(entity::tag::ActiveModel {
            serial_num: ActiveValue::NotSet,
            name: value.name.map_or(ActiveValue::NotSet, ActiveValue::Set),
            description: value
                .description
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl TagUpdate {
    pub fn apply_to_model(self, model: &mut entity::tag::ActiveModel) {
        set_active_value_t!(model, self, name);
        set_active_value_t!(model, self, description);
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
    }
}

impl From<entity::tag::Model> for Tag {
    fn from(value: entity::tag::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: TagBase {
                name: value.name,
                description: value.description,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
