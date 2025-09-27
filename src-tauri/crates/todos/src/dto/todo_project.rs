use chrono::{DateTime, FixedOffset};
use common::utils::date::DateUtils;
use macros::set_active_value_t;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoProjectBase {
    pub order_index: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoProject {
    #[validate(length(equal = 38))]
    pub todo_serial_num: String,
    #[validate(length(equal = 38))]
    pub project_serial_num: String,
    #[serde(flatten)]
    pub core: TodoProjectBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoProjectCreate {
    #[validate(length(equal = 38))]
    pub todo_serial_num: String,
    #[validate(length(equal = 38))]
    pub project_serial_num: String,
    #[serde(flatten)]
    pub core: TodoProjectBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoProjectUpdate {
    pub order_index: Option<Option<i32>>,
}

impl TryFrom<TodoProjectCreate> for entity::todo_project::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TodoProjectCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::todo_project::ActiveModel {
            todo_serial_num: ActiveValue::Set(value.todo_serial_num),
            project_serial_num: ActiveValue::Set(value.project_serial_num),
            order_index: ActiveValue::Set(value.core.order_index),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<TodoProjectUpdate> for entity::todo_project::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TodoProjectUpdate) -> Result<Self, Self::Error> {
        Ok(entity::todo_project::ActiveModel {
            todo_serial_num: ActiveValue::NotSet,
            project_serial_num: ActiveValue::NotSet,
            order_index: value
                .order_index
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl TodoProjectUpdate {
    pub fn apply_to_model(self, model: &mut entity::todo_project::ActiveModel) {
        set_active_value_t!(model, self, order_index);
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
    }
}

impl From<entity::todo_project::Model> for TodoProject {
    fn from(value: entity::todo_project::Model) -> Self {
        Self {
            todo_serial_num: value.todo_serial_num,
            project_serial_num: value.project_serial_num,
            core: TodoProjectBase {
                order_index: value.order_index,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
