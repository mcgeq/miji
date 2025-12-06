//! `SeaORM` Entity for scheduler_config table

use crate::localize::LocalizeModel;
use localize_model_derive::LocalizeModel;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize, LocalizeModel)]
#[sea_orm(table_name = "scheduler_config")]
pub struct Model {
    /// 主键 - UUID 格式
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,

    /// 用户ID - NULL 表示全局配置
    pub user_serial_num: Option<String>,

    /// 任务类型
    pub task_type: String,

    /// 是否启用
    pub enabled: bool,

    /// 执行间隔（秒）
    pub interval_seconds: i32,

    /// 最大重试次数
    pub max_retry_count: Option<i32>,

    /// 重试延迟（秒）
    pub retry_delay_seconds: Option<i32>,

    /// 平台限定：desktop, mobile, android, ios
    pub platform: Option<String>,

    /// 电量阈值（移动端）
    pub battery_threshold: Option<i32>,

    /// 是否需要网络
    pub network_required: bool,

    /// 仅Wi-Fi
    pub wifi_only: bool,

    /// 活动时段开始
    pub active_hours_start: Option<Time>,

    /// 活动时段结束
    pub active_hours_end: Option<Time>,

    /// 优先级 1-10
    pub priority: i32,

    /// 配置描述
    pub description: Option<String>,

    /// 是否为默认配置
    pub is_default: bool,

    /// 创建时间
    pub created_at: DateTimeWithTimeZone,

    /// 更新时间
    pub updated_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    /// 关联到 users 表（可选）
    #[sea_orm(
        belongs_to = "super::users::Entity",
        from = "Column::UserSerialNum",
        to = "super::users::Column::SerialNum"
    )]
    User,
}

impl Related<super::users::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::User.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
