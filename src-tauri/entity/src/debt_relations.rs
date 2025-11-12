//! `SeaORM` Entity for DebtRelations

use crate::localize::LocalizeModel;
use localize_model_derive::LocalizeModel;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize, LocalizeModel)]
#[sea_orm(table_name = "debt_relations")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    pub family_ledger_serial_num: String,
    pub creditor_member_serial_num: String,
    pub debtor_member_serial_num: String,
    pub amount: Decimal,
    pub currency: String,
    pub status: String,
    pub last_updated_by: String,
    pub last_calculated_at: DateTimeWithTimeZone,
    pub settled_at: Option<DateTimeWithTimeZone>,
    pub notes: Option<String>,
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
        from = "Column::CreditorMemberSerialNum",
        to = "super::family_member::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    CreditorMember,
    #[sea_orm(
        belongs_to = "super::family_member::Entity",
        from = "Column::DebtorMemberSerialNum",
        to = "super::family_member::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    DebtorMember,
}

impl Related<super::family_ledger::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::FamilyLedger.def()
    }
}

impl Related<super::family_member::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::CreditorMember.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
