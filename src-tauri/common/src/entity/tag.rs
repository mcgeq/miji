//! `SeaORM` Entity, @generated by sea-orm-codegen 1.1.11

use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq, Serialize, Deserialize)]
#[sea_orm(table_name = "tag")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    #[sea_orm(unique)]
    pub name: String,
    pub description: Option<String>,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::todo_tag::Entity")]
    TodoTag,
}

impl Related<super::todo_tag::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::TodoTag.def()
    }
}

impl Related<super::todo::Entity> for Entity {
    fn to() -> RelationDef {
        super::todo_tag::Relation::Todo.def()
    }
    fn via() -> Option<RelationDef> {
        Some(super::todo_tag::Relation::Tag.def().rev())
    }
}

impl ActiveModelBehavior for ActiveModel {}
