//! `SeaORM` Entity for user_setting_history table

use crate::localize::LocalizeModel;
use localize_model_derive::LocalizeModel;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize, LocalizeModel)]
#[sea_orm(table_name = "user_setting_history")]
pub struct Model {
    /// 主键 - UUID 格式
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    
    /// 用户ID - 外键关联到 users 表
    pub user_serial_num: String,
    
    /// 设置键名
    pub setting_key: String,
    
    /// 旧值 - JSON 格式（null 表示新建）
    #[sea_orm(column_type = "Json", nullable)]
    pub old_value: Option<Json>,
    
    /// 新值 - JSON 格式
    #[sea_orm(column_type = "Json")]
    pub new_value: Json,
    
    /// 变更类型: create, update, delete, reset
    pub change_type: String,
    
    /// 变更来源: user, system, import, sync
    pub changed_by: Option<String>,
    
    /// 操作IP地址
    pub ip_address: Option<String>,
    
    /// 用户代理信息
    #[sea_orm(column_type = "Text", nullable)]
    pub user_agent: Option<String>,
    
    /// 变更时间
    pub created_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    /// 关联到 users 表
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
