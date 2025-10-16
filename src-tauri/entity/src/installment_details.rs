use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize)]
#[sea_orm(table_name = "installment_details")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: String,
    pub plan_id: String,
    pub period_number: i32,
    pub due_date: DateTimeWithTimeZone,
    #[sea_orm(column_type = "Decimal(Some((15, 2)))")]
    pub amount: Decimal,
    pub status: String,
    pub paid_date: Option<DateTimeWithTimeZone>,
    #[sea_orm(column_type = "Decimal(Some((15, 2)))", nullable)]
    pub paid_amount: Option<Decimal>,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::installment_plans::Entity",
        from = "Column::PlanId",
        to = "super::installment_plans::Column::Id"
    )]
    InstallmentPlan,
}

impl Related<super::installment_plans::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::InstallmentPlan.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
