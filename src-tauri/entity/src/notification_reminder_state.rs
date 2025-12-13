//! Notification Reminder State Entity

use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "notification_reminder_states")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,

    pub reminder_type: String,
    pub reminder_serial_num: String,
    pub notification_type: String,

    pub next_scheduled_at: Option<DateTimeWithTimeZone>,
    pub last_sent_at: Option<DateTimeWithTimeZone>,
    pub snooze_until: Option<DateTimeWithTimeZone>,

    pub status: String,
    pub retry_count: i32,
    pub fail_reason: Option<String>,

    pub sent_count: i32,
    pub view_count: i32,
    pub response_time: Option<i32>,

    pub created_at: DateTimeWithTimeZone,
    pub updated_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::notification_reminder_history::Entity")]
    History,
}

impl Related<super::notification_reminder_history::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::History.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
