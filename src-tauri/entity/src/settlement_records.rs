//! `SeaORM` Entity for SettlementRecords

use crate::localize::LocalizeModel;
use localize_model_derive::LocalizeModel;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize, LocalizeModel)]
#[sea_orm(table_name = "settlement_records")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    pub family_ledger_serial_num: String,
    pub settlement_type: String,
    pub period_start: Date,
    pub period_end: Date,
    pub total_amount: Decimal,
    pub currency: String,
    pub participant_members: Json,
    pub settlement_details: Json,
    pub optimized_transfers: Option<Json>,
    pub status: String,
    pub initiated_by: String,
    pub completed_by: Option<String>,
    pub description: Option<String>,
    pub notes: Option<String>,
    pub completed_at: Option<DateTimeWithTimeZone>,
    pub cancelled_at: Option<DateTimeWithTimeZone>,
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
    #[sea_orm(
        belongs_to = "super::family_member::Entity",
        from = "Column::InitiatedBy",
        to = "super::family_member::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Restrict"
    )]
    InitiatedByMember,
    #[sea_orm(
        belongs_to = "super::family_member::Entity",
        from = "Column::CompletedBy",
        to = "super::family_member::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "SetNull"
    )]
    CompletedByMember,
}

impl Related<super::family_ledger::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::FamilyLedger.def()
    }
}

impl Related<super::family_member::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::InitiatedByMember.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
