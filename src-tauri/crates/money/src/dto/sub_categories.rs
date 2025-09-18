use chrono::{DateTime, FixedOffset};
use common::utils::date::DateUtils;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SubCategoryBase {
    pub name: String,
    pub icon: Option<String>,
    pub category_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SubCategory {
    #[serde(flatten)]
    pub core: SubCategoryBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SubCategoryCreate {
    #[serde(flatten)]
    pub core: SubCategoryBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct SubCategoryUpdate {
    pub name: Option<String>,
    pub icon: Option<String>,
    pub category_name: Option<String>,
}

impl TryFrom<SubCategoryCreate> for entity::sub_categories::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: SubCategoryCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::sub_categories::ActiveModel {
            name: ActiveValue::Set(value.core.name),
            icon: ActiveValue::Set(value.core.icon),
            category_name: ActiveValue::Set(value.core.category_name),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<SubCategoryUpdate> for entity::sub_categories::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: SubCategoryUpdate) -> Result<Self, Self::Error> {
        Ok(entity::sub_categories::ActiveModel {
            name: value.name.map_or(ActiveValue::NotSet, ActiveValue::Set),
            icon: value
                .icon
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            category_name: value
                .category_name
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl From<entity::sub_categories::Model> for SubCategory {
    fn from(value: entity::sub_categories::Model) -> Self {
        Self {
            core: SubCategoryBase {
                name: value.name,
                icon: value.icon,
                category_name: value.category_name,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
