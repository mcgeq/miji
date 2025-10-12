use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::{EmptyFilter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, DbConn, prelude::async_trait::async_trait};

use crate::{
    dto::sub_categories::{SubCategoryCreate, SubCategoryUpdate},
    services::sub_categories_hooks::SubCategoryHooks,
};

pub type SubCategoryFilter = EmptyFilter;

#[derive(Debug)]
pub struct SubCategoryConverter;

impl CrudConverter<entity::sub_categories::Entity, SubCategoryCreate, SubCategoryUpdate>
    for SubCategoryConverter
{
    fn create_to_active_model(
        &self,
        data: SubCategoryCreate,
    ) -> MijiResult<entity::sub_categories::ActiveModel> {
        entity::sub_categories::ActiveModel::try_from(data)
            .map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::sub_categories::Model,
        data: SubCategoryUpdate,
    ) -> MijiResult<entity::sub_categories::ActiveModel> {
        entity::sub_categories::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.name = ActiveValue::Set(model.name.clone());
                active_model.category_name = ActiveValue::Set(model.category_name.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::sub_categories::Model) -> String {
        format!("{}:{}", model.category_name, model.name)
    }

    fn table_name(&self) -> &'static str {
        "sub_categories"
    }
}

#[async_trait]
impl LocalizableConverter<entity::sub_categories::Model> for SubCategoryConverter {
    async fn model_with_local(
        &self,
        model: entity::sub_categories::Model,
    ) -> MijiResult<entity::sub_categories::Model> {
        Ok(model.to_local())
    }
}

impl SubCategoryConverter {
    pub fn parse_id(id: &str) -> (String, String) {
        let mut parts = id.splitn(2, ':');
        let category_name = parts.next().unwrap_or_default().to_string();
        let name = parts.next().unwrap_or_default().to_string();
        (category_name, name)
    }
}

pub struct SubCategoryService {
    inner: GenericCrudService<
        entity::sub_categories::Entity,
        SubCategoryFilter,
        SubCategoryCreate,
        SubCategoryUpdate,
        SubCategoryConverter,
        SubCategoryHooks,
    >,
}

impl SubCategoryService {
    pub fn new(
        converter: SubCategoryConverter,
        hooks: SubCategoryHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for SubCategoryService {
    type Target = GenericCrudService<
        entity::sub_categories::Entity,
        SubCategoryFilter,
        SubCategoryCreate,
        SubCategoryUpdate,
        SubCategoryConverter,
        SubCategoryHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl SubCategoryService {
    // 根据拼接 ID 查询
    pub async fn sub_category_get(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<entity::sub_categories::Model> {
        let id_tuple = SubCategoryConverter::parse_id(&id);
        let model = self.inner.get_by_id(db, id_tuple).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn sub_category_create(
        &self,
        db: &DbConn,
        data: SubCategoryCreate,
    ) -> MijiResult<entity::sub_categories::Model> {
        let model = self.inner.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn sub_category_update(
        &self,
        db: &DbConn,
        id: String,
        data: SubCategoryUpdate,
    ) -> MijiResult<entity::sub_categories::Model> {
        let id_tuple = SubCategoryConverter::parse_id(&id);
        let model = self.inner.update(db, id_tuple, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn sub_category_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        let id_tuple = SubCategoryConverter::parse_id(&id);
        self.inner.delete(db, id_tuple).await
    }

    pub async fn sub_category_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<SubCategoryFilter>,
    ) -> MijiResult<PagedResult<entity::sub_categories::Model>> {
        self.inner.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    pub async fn sub_category_list(
        &self,
        db: &DbConn,
    ) -> MijiResult<Vec<entity::sub_categories::Model>> {
        let models = self.inner.list(db).await?;
        // 对每个 Model 调用 model_with_local
        let mut local_models = Vec::with_capacity(models.len());
        for model in models {
            local_models.push(self.converter().model_with_local(model).await?);
        }
        Ok(local_models)
    }
}

pub fn get_sub_category_service() -> SubCategoryService {
    SubCategoryService::new(
        SubCategoryConverter,
        SubCategoryHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
