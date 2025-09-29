use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use entity::todo::{Priority, Status};
use macros::{set_active_value_opt, set_active_value_t};
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoBase {
    pub title: String,
    pub description: Option<String>,
    pub due_at: DateTime<FixedOffset>,
    pub priority: Priority,
    pub status: Status,
    pub repeat_period_type: String,
    pub repeat: serde_json::Value,
    pub completed_at: Option<DateTime<FixedOffset>>,
    pub assignee_id: Option<String>,
    pub progress: i32,
    pub location: Option<String>,
    pub owner_id: Option<String>,
    pub is_archived: bool,
    pub is_pinned: bool,
    pub estimate_minutes: Option<i32>,
    pub reminder_count: i32,
    pub parent_id: Option<String>,
    pub subtask_order: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct Todo {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: TodoBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoCreate {
    #[serde(flatten)]
    pub core: TodoBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoUpdate {
    pub title: Option<String>,
    pub description: Option<String>,
    pub due_at: Option<DateTime<FixedOffset>>,
    pub priority: Option<Priority>,
    pub status: Option<Status>,
    pub repeat_period_type: Option<String>,
    pub repeat: Option<serde_json::Value>,
    pub completed_at: Option<DateTime<FixedOffset>>,
    pub assignee_id: Option<String>,
    pub progress: Option<i32>,
    pub location: Option<String>,
    pub owner_id: Option<String>,
    pub is_archived: Option<bool>,
    pub is_pinned: Option<bool>,
    pub estimate_minutes: Option<i32>,
    pub reminder_count: Option<i32>,
    pub parent_id: Option<String>,
    pub subtask_order: Option<i32>,
}

impl TryFrom<TodoCreate> for entity::todo::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TodoCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::todo::ActiveModel {
            serial_num: ActiveValue::Set(McgUuid::uuid(38)),
            title: ActiveValue::Set(value.core.title),
            description: ActiveValue::Set(value.core.description),
            due_at: ActiveValue::Set(value.core.due_at),
            priority: ActiveValue::Set(value.core.priority),
            status: ActiveValue::Set(value.core.status),
            repeat_period_type: ActiveValue::Set(value.core.repeat_period_type),
            repeat: ActiveValue::Set(value.core.repeat),
            completed_at: ActiveValue::Set(value.core.completed_at),
            assignee_id: ActiveValue::Set(value.core.assignee_id),
            progress: ActiveValue::Set(value.core.progress),
            location: ActiveValue::Set(value.core.location),
            owner_id: ActiveValue::Set(value.core.owner_id),
            is_archived: ActiveValue::Set(value.core.is_archived),
            is_pinned: ActiveValue::Set(value.core.is_pinned),
            estimate_minutes: ActiveValue::Set(value.core.estimate_minutes),
            reminder_count: ActiveValue::Set(value.core.reminder_count),
            parent_id: ActiveValue::Set(value.core.parent_id),
            subtask_order: ActiveValue::Set(value.core.subtask_order),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<TodoUpdate> for entity::todo::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TodoUpdate) -> Result<Self, Self::Error> {
        Ok(entity::todo::ActiveModel {
            serial_num: ActiveValue::NotSet,
            title: value.title.map_or(ActiveValue::NotSet, ActiveValue::Set),
            description: value
                .description
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            due_at: value.due_at.map_or(ActiveValue::NotSet, ActiveValue::Set),
            priority: value.priority.map_or(ActiveValue::NotSet, ActiveValue::Set),
            status: value.status.map_or(ActiveValue::NotSet, ActiveValue::Set),
            repeat_period_type: value
                .repeat_period_type
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            repeat: value.repeat.map_or(ActiveValue::NotSet, ActiveValue::Set),
            completed_at: value
                .completed_at
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            assignee_id: value
                .assignee_id
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            progress: value.progress.map_or(ActiveValue::NotSet, ActiveValue::Set),
            location: value
                .location
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            owner_id: value
                .owner_id
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            is_archived: value
                .is_archived
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            is_pinned: value
                .is_pinned
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            estimate_minutes: value
                .estimate_minutes
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            reminder_count: value
                .reminder_count
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            parent_id: value
                .parent_id
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            subtask_order: value
                .subtask_order
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl TodoUpdate {
    pub fn apply_to_model(self, model: &mut entity::todo::ActiveModel) {
        set_active_value_t!(model, self, title);
        set_active_value_opt!(model, self, description);
        set_active_value_t!(model, self, due_at);
        set_active_value_t!(model, self, priority);
        set_active_value_t!(model, self, status);
        set_active_value_t!(model, self, repeat);
        set_active_value_t!(model, self, repeat_period_type);
        set_active_value_opt!(model, self, completed_at);
        set_active_value_opt!(model, self, assignee_id);
        set_active_value_t!(model, self, progress);
        set_active_value_opt!(model, self, location);
        set_active_value_opt!(model, self, owner_id);
        set_active_value_t!(model, self, is_archived);
        set_active_value_t!(model, self, is_pinned);
        set_active_value_opt!(model, self, estimate_minutes);
        set_active_value_t!(model, self, reminder_count);
        set_active_value_opt!(model, self, parent_id);
        set_active_value_opt!(model, self, subtask_order);
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
    }
}

impl From<entity::todo::Model> for Todo {
    fn from(value: entity::todo::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: TodoBase {
                title: value.title,
                description: value.description,
                due_at: value.due_at,
                priority: value.priority,
                status: value.status,
                repeat_period_type: value.repeat_period_type,
                repeat: value.repeat,
                completed_at: value.completed_at,
                assignee_id: value.assignee_id,
                progress: value.progress,
                location: value.location,
                owner_id: value.owner_id,
                is_archived: value.is_archived,
                is_pinned: value.is_pinned,
                estimate_minutes: value.estimate_minutes,
                reminder_count: value.reminder_count,
                parent_id: value.parent_id,
                subtask_order: value.subtask_order,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
