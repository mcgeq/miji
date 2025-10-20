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
    // 新增提醒相关字段
    pub reminder_enabled: bool,
    pub reminder_advance_value: Option<i32>,
    pub reminder_advance_unit: Option<String>,
    pub last_reminder_sent_at: Option<DateTime<FixedOffset>>,
    pub reminder_frequency: Option<String>,
    pub snooze_until: Option<DateTime<FixedOffset>>,
    pub reminder_methods: Option<serde_json::Value>,
    pub timezone: Option<String>,
    pub smart_reminder_enabled: bool,
    pub location_based_reminder: bool,
    pub weather_dependent: bool,
    pub priority_boost_enabled: bool,
    pub batch_reminder_id: Option<String>,
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
    // 新增提醒相关字段
    pub reminder_enabled: Option<bool>,
    pub reminder_advance_value: Option<i32>,
    pub reminder_advance_unit: Option<String>,
    pub last_reminder_sent_at: Option<DateTime<FixedOffset>>,
    pub reminder_frequency: Option<String>,
    pub snooze_until: Option<DateTime<FixedOffset>>,
    pub reminder_methods: Option<serde_json::Value>,
    pub timezone: Option<String>,
    pub smart_reminder_enabled: Option<bool>,
    pub location_based_reminder: Option<bool>,
    pub weather_dependent: Option<bool>,
    pub priority_boost_enabled: Option<bool>,
    pub batch_reminder_id: Option<String>,
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
            // 新增提醒相关字段
            reminder_enabled: ActiveValue::Set(value.core.reminder_enabled),
            reminder_advance_value: ActiveValue::Set(value.core.reminder_advance_value),
            reminder_advance_unit: ActiveValue::Set(value.core.reminder_advance_unit),
            last_reminder_sent_at: ActiveValue::Set(value.core.last_reminder_sent_at),
            reminder_frequency: ActiveValue::Set(value.core.reminder_frequency),
            snooze_until: ActiveValue::Set(value.core.snooze_until),
            reminder_methods: ActiveValue::Set(value.core.reminder_methods),
            timezone: ActiveValue::Set(value.core.timezone),
            smart_reminder_enabled: ActiveValue::Set(value.core.smart_reminder_enabled),
            location_based_reminder: ActiveValue::Set(value.core.location_based_reminder),
            weather_dependent: ActiveValue::Set(value.core.weather_dependent),
            priority_boost_enabled: ActiveValue::Set(value.core.priority_boost_enabled),
            batch_reminder_id: ActiveValue::Set(value.core.batch_reminder_id),
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
            // 新增提醒相关字段
            reminder_enabled: value
                .reminder_enabled
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            reminder_advance_value: value
                .reminder_advance_value
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            reminder_advance_unit: value
                .reminder_advance_unit
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            last_reminder_sent_at: value
                .last_reminder_sent_at
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            reminder_frequency: value
                .reminder_frequency
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            snooze_until: value
                .snooze_until
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            reminder_methods: value
                .reminder_methods
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            timezone: value
                .timezone
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            smart_reminder_enabled: value
                .smart_reminder_enabled
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            location_based_reminder: value
                .location_based_reminder
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            weather_dependent: value
                .weather_dependent
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            priority_boost_enabled: value
                .priority_boost_enabled
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            batch_reminder_id: value
                .batch_reminder_id
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
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
        // 新增提醒相关字段
        set_active_value_t!(model, self, reminder_enabled);
        set_active_value_opt!(model, self, reminder_advance_value);
        set_active_value_opt!(model, self, reminder_advance_unit);
        set_active_value_opt!(model, self, last_reminder_sent_at);
        set_active_value_opt!(model, self, reminder_frequency);
        set_active_value_opt!(model, self, snooze_until);
        set_active_value_opt!(model, self, reminder_methods);
        set_active_value_opt!(model, self, timezone);
        set_active_value_t!(model, self, smart_reminder_enabled);
        set_active_value_t!(model, self, location_based_reminder);
        set_active_value_t!(model, self, weather_dependent);
        set_active_value_t!(model, self, priority_boost_enabled);
        set_active_value_opt!(model, self, batch_reminder_id);
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
                // 新增提醒相关字段
                reminder_enabled: value.reminder_enabled,
                reminder_advance_value: value.reminder_advance_value,
                reminder_advance_unit: value.reminder_advance_unit,
                last_reminder_sent_at: value.last_reminder_sent_at,
                reminder_frequency: value.reminder_frequency,
                snooze_until: value.snooze_until,
                reminder_methods: value.reminder_methods,
                timezone: value.timezone,
                smart_reminder_enabled: value.smart_reminder_enabled,
                location_based_reminder: value.location_based_reminder,
                weather_dependent: value.weather_dependent,
                priority_boost_enabled: value.priority_boost_enabled,
                batch_reminder_id: value.batch_reminder_id,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
