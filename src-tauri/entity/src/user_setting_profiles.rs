//! `SeaORM` Entity for user_setting_profiles table

use crate::localize::LocalizeModel;
use localize_model_derive::LocalizeModel;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize, LocalizeModel)]
#[sea_orm(table_name = "user_setting_profiles")]
pub struct Model {
    /// 主键 - UUID 格式
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,

    /// 用户ID - 外键关联到 users 表
    pub user_serial_num: String,

    /// 配置文件名称，如: 默认、工作、家庭
    pub profile_name: String,

    /// 完整的设置配置数据 - JSON 格式
    #[sea_orm(column_type = "Json")]
    pub profile_data: Json,

    /// 是否为当前激活的配置
    pub is_active: bool,

    /// 是否为默认配置（不可删除）
    pub is_default: bool,

    /// 配置描述（可选）
    pub description: Option<String>,

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
