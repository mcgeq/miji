use common::{crud::hooks::Hooks, error::MijiResult, utils::date::DateUtils};
use entity::family_member;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, DatabaseTransaction, prelude::async_trait::async_trait,
};

use crate::dto::users::{CreateUserDto, UpdateUserDto};

pub struct UserHooks;

#[async_trait]
impl Hooks<entity::users::Entity, CreateUserDto, UpdateUserDto> for UserHooks {
    async fn before_create(
        &self,
        _tx: &DatabaseTransaction,
        _data: &CreateUserDto,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_create(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::users::Model,
    ) -> MijiResult<()> {
        let family_member_model = family_member::ActiveModel {
            serial_num: Set(model.serial_num.clone()),
            name: Set(model.name.clone()),
            role: Set("Admin".to_string()),
            is_primary: Set(false),
            permissions: Set("".to_string()),
            created_at: Set(DateUtils::local_now()),
            updated_at: Set(None),
        };
        family_member_model.insert(tx).await?;
        Ok(())
    }

    async fn before_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::users::Model,
        _data: &UpdateUserDto,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_update(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::users::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn before_delete(
        &self,
        _tx: &DatabaseTransaction,
        _model: &entity::users::Model,
    ) -> MijiResult<()> {
        Ok(())
    }

    async fn after_delete(&self, _tx: &DatabaseTransaction, _id: &String) -> MijiResult<()> {
        Ok(())
    }
}
