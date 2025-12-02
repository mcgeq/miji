//! `SeaORM` Entity for user_settings table

use crate::localize::LocalizeModel;
use localize_model_derive::LocalizeModel;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize, LocalizeModel)]
#[sea_orm(table_name = "user_settings")]
pub struct Model {
    /// 主键 - UUID 格式
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    
    /// 用户ID - 外键关联到 users 表
    pub user_serial_num: String,
    
    /// 设置键名，格式: settings.{module}.{field}
    /// 例如: settings.general.theme, settings.notification.enabled
    pub setting_key: String,
    
    /// 设置值 - JSON 格式，支持任意类型
    #[sea_orm(column_type = "Json")]
    pub setting_value: Json,
    
    /// 值类型: string, number, boolean, object, array
    pub setting_type: String,
    
    /// 所属模块: general, notification, privacy, security
    pub module: String,
    
    /// 设置描述（可选）
    pub description: Option<String>,
    
    /// 是否为默认值
    pub is_default: bool,
    
    /// 创建时间
    pub created_at: DateTimeWithTimeZone,
    
    /// 最后更新时间
    pub updated_at: DateTimeWithTimeZone,
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
