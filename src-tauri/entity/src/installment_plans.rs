use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize)]
#[sea_orm(table_name = "installment_plans")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    pub transaction_serial_num: String,
    #[sea_orm(column_type = "Decimal(Some((15, 2)))")]
    pub total_amount: Decimal,
    pub total_periods: i32,
    #[sea_orm(column_type = "Decimal(Some((15, 2)))")]
    pub installment_amount: Decimal,
    pub first_due_date: DateTimeWithTimeZone,
    pub status: String,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::transactions::Entity",
        from = "Column::TransactionSerialNum",
        to = "super::transactions::Column::SerialNum"
    )]
    Transaction,

    #[sea_orm(has_many = "super::installment_details::Entity")]
    InstallmentDetails,
}

impl Related<super::transactions::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Transaction.def()
    }
}

impl Related<super::installment_details::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::InstallmentDetails.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
