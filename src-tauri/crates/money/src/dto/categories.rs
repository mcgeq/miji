use chrono::{DateTime, FixedOffset};
use common::utils::date::DateUtils;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct CategoryBase {
    pub name: String,
    pub icon: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct Category {
    #[serde(flatten)]
    pub core: CategoryBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct CategoryCreate {
    #[serde(flatten)]
    pub core: CategoryBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct CategoryUpdate {
    pub name: Option<String>,
    pub icon: Option<String>,
}

impl TryFrom<CategoryCreate> for entity::categories::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: CategoryCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::categories::ActiveModel {
            name: ActiveValue::Set(value.core.name),
            icon: ActiveValue::Set(value.core.icon),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<CategoryUpdate> for entity::categories::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: CategoryUpdate) -> Result<Self, Self::Error> {
        Ok(entity::categories::ActiveModel {
            name: value.name.map_or(ActiveValue::NotSet, ActiveValue::Set),
            icon: value
                .icon
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl From<entity::categories::Model> for Category {
    fn from(value: entity::categories::Model) -> Self {
        Self {
            core: CategoryBase {
                name: value.name,
                icon: value.icon,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
