use std::{collections::HashMap, sync::Arc};

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::{EmptyFilter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{
    ActiveValue, ColumnTrait, DbConn, EntityTrait, QueryFilter, prelude::async_trait::async_trait,
};

use crate::{
    dto::family_member::{FamilyMemberCreate, FamilyMemberUpdate},
    services::family_member_hooks::FamilyMemberHooks,
};

pub type FamilyMemberFilter = EmptyFilter;

#[derive(Debug)]
pub struct FamilyMemberConverter;

impl CrudConverter<entity::family_member::Entity, FamilyMemberCreate, FamilyMemberUpdate>
    for FamilyMemberConverter
{
    fn create_to_active_model(
        &self,
        data: FamilyMemberCreate,
    ) -> MijiResult<entity::family_member::ActiveModel> {
        entity::family_member::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::family_member::Model,
        data: FamilyMemberUpdate,
    ) -> MijiResult<entity::family_member::ActiveModel> {
        entity::family_member::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.name = ActiveValue::Set(model.name.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::family_member::Model) -> String {
        model.name.clone()
    }

    fn table_name(&self) -> &'static str {
        "family_member"
    }
}

#[async_trait]
impl LocalizableConverter<entity::family_member::Model> for FamilyMemberConverter {
    async fn model_with_local(
        &self,
        model: entity::family_member::Model,
    ) -> MijiResult<entity::family_member::Model> {
        Ok(model.to_local())
    }
}

pub struct FamilyMemberService {
    inner: GenericCrudService<
        entity::family_member::Entity,
        FamilyMemberFilter,
        FamilyMemberCreate,
        FamilyMemberUpdate,
        FamilyMemberConverter,
        FamilyMemberHooks,
    >,
}

impl FamilyMemberService {
    pub fn new(
        converter: FamilyMemberConverter,
        hooks: FamilyMemberHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for FamilyMemberService {
    type Target = GenericCrudService<
        entity::family_member::Entity,
        FamilyMemberFilter,
        FamilyMemberCreate,
        FamilyMemberUpdate,
        FamilyMemberConverter,
        FamilyMemberHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl FamilyMemberService {
    pub async fn family_member_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::family_member::Model> {
        let model = self.get_by_id(db, serial_num).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn family_member_create(
        &self,
        db: &DbConn,
        data: FamilyMemberCreate,
    ) -> MijiResult<entity::family_member::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn family_member_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: FamilyMemberUpdate,
    ) -> MijiResult<entity::family_member::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn family_member_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn family_member_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<FamilyMemberFilter>,
    ) -> MijiResult<PagedResult<entity::family_member::Model>> {
        self.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    pub async fn family_member_list(
        &self,
        db: &DbConn,
    ) -> MijiResult<Vec<entity::family_member::Model>> {
        let models = self.list(db).await?;
        // 对每个 Model 调用 model_with_local
        let mut local_models = Vec::with_capacity(models.len());
        for model in models {
            local_models.push(self.converter().model_with_local(model).await?);
        }
        Ok(local_models)
    }

    pub async fn family_member_batch_get(
        &self,
        db: &DbConn,
        ids: &[String],
    ) -> MijiResult<HashMap<String, entity::family_member::Model>> {
        if ids.is_empty() {
            return Ok(HashMap::new());
        }
        const CHUNK_SIZE: usize = 1000;
        let mut result = HashMap::new();
        for chunk in ids.chunks(CHUNK_SIZE) {
            let owners = entity::family_member::Entity::find()
                .filter(entity::family_member::Column::SerialNum.is_in(chunk))
                .all(db)
                .await
                .map_err(AppError::from)?;
            result.extend(
                owners
                    .into_iter()
                    .map(|owner| (owner.serial_num.clone(), owner.to_local())),
            );
        }
        Ok(result)
    }
}

pub fn get_family_member_service() -> FamilyMemberService {
    FamilyMemberService::new(
        FamilyMemberConverter,
        FamilyMemberHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
