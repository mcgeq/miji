//! Notification Reminder History Entity

use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "notification_reminder_history")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,

    pub reminder_state_serial_num: String,
    pub reminder_type: String,
    pub reminder_serial_num: String,

    pub sent_at: DateTimeWithTimeZone,
    pub sent_methods: String,
    pub sent_channels: Option<String>,

    pub status: String,
    pub fail_reason: Option<String>,

    pub viewed_at: Option<DateTimeWithTimeZone>,
    pub dismissed_at: Option<DateTimeWithTimeZone>,
    pub action_taken: Option<String>,

    pub user_location: Option<String>,
    pub device_info: Option<String>,

    pub created_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::notification_reminder_state::Entity",
        from = "Column::ReminderStateSerialNum",
        to = "super::notification_reminder_state::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    ReminderState,
}

impl Related<super::notification_reminder_state::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::ReminderState.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
