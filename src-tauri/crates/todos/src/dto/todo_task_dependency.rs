use chrono::{DateTime, FixedOffset};
use common::utils::date::DateUtils;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TaskDependencyBase {}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TaskDependency {
    #[validate(length(equal = 38))]
    pub task_serial_num: String,
    #[validate(length(equal = 38))]
    pub depends_on_task_serial_num: String,
    #[serde(flatten)]
    pub core: TaskDependencyBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TaskDependencyCreate {
    #[validate(length(equal = 38))]
    pub task_serial_num: String,
    #[validate(length(equal = 38))]
    pub depends_on_task_serial_num: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TaskDependencyUpdate {}

impl TryFrom<TaskDependencyCreate> for entity::task_dependency::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: TaskDependencyCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::task_dependency::ActiveModel {
            task_serial_num: ActiveValue::Set(value.task_serial_num),
            depends_on_task_serial_num: ActiveValue::Set(value.depends_on_task_serial_num),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<TaskDependencyUpdate> for entity::task_dependency::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(_value: TaskDependencyUpdate) -> Result<Self, Self::Error> {
        Ok(entity::task_dependency::ActiveModel {
            task_serial_num: ActiveValue::NotSet,
            depends_on_task_serial_num: ActiveValue::NotSet,
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl TaskDependencyUpdate {
    pub fn apply_to_model(self, model: &mut entity::task_dependency::ActiveModel) {
        // TaskDependency 没有可选字段，只有更新时间
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
    }
}

impl From<entity::task_dependency::Model> for TaskDependency {
    fn from(value: entity::task_dependency::Model) -> Self {
        Self {
            task_serial_num: value.task_serial_num,
            depends_on_task_serial_num: value.depends_on_task_serial_num,
            core: TaskDependencyBase {},
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
