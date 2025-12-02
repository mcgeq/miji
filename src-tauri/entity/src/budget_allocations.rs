//! `SeaORM` Entity. Budget Allocations

use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize)]
#[sea_orm(table_name = "budget_allocations")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    pub budget_serial_num: String,
    pub category_serial_num: Option<String>, // null = 所有分类
    pub member_serial_num: Option<String>,   // null = 所有成员
    #[sea_orm(column_type = "Decimal(Some((15, 2)))")]
    pub allocated_amount: Decimal,
    #[sea_orm(column_type = "Decimal(Some((15, 2)))")]
    pub used_amount: Decimal,
    #[sea_orm(column_type = "Decimal(Some((15, 2)))")]
    pub remaining_amount: Decimal,
    #[sea_orm(column_type = "Decimal(Some((5, 2)))")]
    pub percentage: Option<Decimal>, // 占总预算的百分比
    // 增强字段 - 分配规则
    pub allocation_type: String,
    #[sea_orm(column_type = "JsonBinary")]
    pub rule_config: Option<Json>,
    // 增强字段 - 超支控制
    pub allow_overspend: bool,
    pub overspend_limit_type: Option<String>,
    #[sea_orm(column_type = "Decimal(Some((10, 2)))")]
    pub overspend_limit_value: Option<Decimal>,
    // 增强字段 - 预警设置
    pub alert_enabled: bool,
    pub alert_threshold: i32,
    #[sea_orm(column_type = "JsonBinary")]
    pub alert_config: Option<Json>,
    // 增强字段 - 管理
    pub priority: i32,
    pub is_mandatory: bool,
    pub status: String,
    pub notes: Option<String>,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::budget::Entity",
        from = "Column::BudgetSerialNum",
        to = "super::budget::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    Budget,
}

impl Related<super::budget::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Budget.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
