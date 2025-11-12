//! `SeaORM` Entity for SplitRecords

use crate::localize::LocalizeModel;
use localize_model_derive::LocalizeModel;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize, LocalizeModel)]
#[sea_orm(table_name = "split_records")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    pub transaction_serial_num: String,
    pub family_ledger_serial_num: String,
    pub split_rule_serial_num: Option<String>,
    pub payer_member_serial_num: String,
    pub owe_member_serial_num: String,
    pub total_amount: Decimal,
    pub split_amount: Decimal,
    pub split_percentage: Option<Decimal>,
    pub currency: String,
    pub status: String,
    pub split_type: String,
    pub description: Option<String>,
    pub notes: Option<String>,
    pub confirmed_at: Option<DateTimeWithTimeZone>,
    pub paid_at: Option<DateTimeWithTimeZone>,
    pub due_date: Option<Date>,
    pub reminder_sent: bool,
    pub last_reminder_at: Option<DateTimeWithTimeZone>,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::transactions::Entity",
        from = "Column::TransactionSerialNum",
        to = "super::transactions::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    Transactions,
    #[sea_orm(
        belongs_to = "super::family_ledger::Entity",
        from = "Column::FamilyLedgerSerialNum",
        to = "super::family_ledger::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    FamilyLedger,
    #[sea_orm(
        belongs_to = "super::split_rules::Entity",
        from = "Column::SplitRuleSerialNum",
        to = "super::split_rules::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "SetNull"
    )]
    SplitRules,
    #[sea_orm(
        belongs_to = "super::family_member::Entity",
        from = "Column::PayerMemberSerialNum",
        to = "super::family_member::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    PayerMember,
    #[sea_orm(
        belongs_to = "super::family_member::Entity",
        from = "Column::OweMemberSerialNum",
        to = "super::family_member::Column::SerialNum",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    OweMember,
}

impl Related<super::transactions::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Transactions.def()
    }
}

impl Related<super::family_ledger::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::FamilyLedger.def()
    }
}

impl Related<super::split_rules::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::SplitRules.def()
    }
}

impl Related<super::family_member::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::PayerMember.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
