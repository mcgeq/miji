use chrono::{DateTime, FixedOffset};
use common::utils::date::DateUtils;
use macros::set_active_value_t;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoTagBase {
    pub orders: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoTag {
    #[validate(length(equal = 38))]
    pub todo_serial_num: String,
    #[validate(length(equal = 38))]
    pub tag_serial_num: String,
    #[serde(flatten)]
    pub core: TodoTagBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoTagCreate {
    #[validate(length(equal = 38))]
    pub todo_serial_num: String,
    #[validate(length(equal = 38))]
    pub tag_serial_num: String,
    #[serde(flatten)]
    pub core: TodoTagBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoTagUpdate {
    pub orders: Option<Option<i32>>,
}

impl TryFrom<TodoTagCreate> for entity::todo_tag::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TodoTagCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::todo_tag::ActiveModel {
            todo_serial_num: ActiveValue::Set(value.todo_serial_num),
            tag_serial_num: ActiveValue::Set(value.tag_serial_num),
            orders: ActiveValue::Set(value.core.orders),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<TodoTagUpdate> for entity::todo_tag::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TodoTagUpdate) -> Result<Self, Self::Error> {
        Ok(entity::todo_tag::ActiveModel {
            todo_serial_num: ActiveValue::NotSet,
            tag_serial_num: ActiveValue::NotSet,
            orders: value.orders.map_or(ActiveValue::NotSet, ActiveValue::Set),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl TodoTagUpdate {
    pub fn apply_to_model(self, model: &mut entity::todo_tag::ActiveModel) {
        set_active_value_t!(model, self, orders);
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
    }
}

impl From<entity::todo_tag::Model> for TodoTag {
    fn from(value: entity::todo_tag::Model) -> Self {
        Self {
            todo_serial_num: value.todo_serial_num,
            tag_serial_num: value.tag_serial_num,
            core: TodoTagBase {
                orders: value.orders,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
