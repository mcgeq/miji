//! `SeaORM` Entity for SplitRecordDetails

use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize)]
#[sea_orm(table_name = "split_record_details")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    pub split_record_serial_num: String,
    pub member_serial_num: String,
    pub amount: Decimal,
    pub percentage: Option<Decimal>,
    pub weight: Option<i32>,
    pub is_paid: bool,
    pub paid_at: Option<DateTimeWithTimeZone>,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::split_records::Entity",
        from = "Column::SplitRecordSerialNum",
        to = "super::split_records::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    SplitRecords,
    #[sea_orm(
        belongs_to = "super::family_member::Entity",
        from = "Column::MemberSerialNum",
        to = "super::family_member::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    FamilyMember,
}

impl Related<super::split_records::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::SplitRecords.def()
    }
}

impl Related<super::family_member::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::FamilyMember.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
