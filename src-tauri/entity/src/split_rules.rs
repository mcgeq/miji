//! `SeaORM` Entity for SplitRules

use crate::localize::LocalizeModel;
use localize_model_derive::LocalizeModel;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize, LocalizeModel)]
#[sea_orm(table_name = "split_rules")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    pub family_ledger_serial_num: String,
    pub name: String,
    pub description: Option<String>,
    pub rule_type: String,
    pub rule_config: Json,
    pub participant_members: Json,
    pub is_template: bool,
    pub is_default: bool,
    pub category: Option<String>,
    pub sub_category: Option<String>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
    pub tags: Option<Json>,
    pub priority: i32,
    pub is_active: bool,
    pub created_by: String,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::family_ledger::Entity",
        from = "Column::FamilyLedgerSerialNum",
        to = "super::family_ledger::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    FamilyLedger,
    #[sea_orm(has_many = "super::split_records::Entity")]
    SplitRecords,
}

impl Related<super::family_ledger::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::FamilyLedger.def()
    }
}

impl Related<super::split_records::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::SplitRecords.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
