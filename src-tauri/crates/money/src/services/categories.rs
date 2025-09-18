use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, Condition, DbConn, prelude::async_trait::async_trait};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::categories::{CategoryCreate, CategoryUpdate},
    services::categories_hooks::CategoryHooks,
};

#[derive(Debug, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct CategoryFilter {}

impl Filter<entity::categories::Entity> for CategoryFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        Condition::all()
    }
}

#[derive(Debug)]
pub struct CategoryConverter;

impl CrudConverter<entity::categories::Entity, CategoryCreate, CategoryUpdate>
    for CategoryConverter
{
    fn create_to_active_model(
        &self,
        data: CategoryCreate,
    ) -> MijiResult<entity::categories::ActiveModel> {
        entity::categories::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::categories::Model,
        data: CategoryUpdate,
    ) -> MijiResult<entity::categories::ActiveModel> {
        entity::categories::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.name = ActiveValue::Set(model.name.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::categories::Model) -> String {
        model.name.clone()
    }

    fn table_name(&self) -> &'static str {
        "categories"
    }
}

impl CategoryConverter {
    pub async fn model_with_local(
        &self,
        model: entity::categories::Model,
    ) -> MijiResult<entity::categories::Model> {
        Ok(model.to_local())
    }
}

pub struct CategoryService {
    inner: GenericCrudService<
        entity::categories::Entity,
        CategoryFilter,
        CategoryCreate,
        CategoryUpdate,
        CategoryConverter,
        CategoryHooks,
    >,
}

impl CategoryService {
    pub fn new(
        converter: CategoryConverter,
        hooks: CategoryHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for CategoryService {
    type Target = GenericCrudService<
        entity::categories::Entity,
        CategoryFilter,
        CategoryCreate,
        CategoryUpdate,
        CategoryConverter,
        CategoryHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

#[async_trait]
impl CrudService<entity::categories::Entity, CategoryFilter, CategoryCreate, CategoryUpdate>
    for CategoryService
{
    async fn create(
        &self,
        db: &DbConn,
        data: CategoryCreate,
    ) -> MijiResult<entity::categories::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(&self, db: &DbConn, id: String) -> MijiResult<entity::categories::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: CategoryUpdate,
    ) -> MijiResult<entity::categories::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::categories::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: CategoryFilter,
    ) -> MijiResult<Vec<entity::categories::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<CategoryFilter>,
    ) -> MijiResult<PagedResult<entity::categories::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<CategoryCreate>,
    ) -> MijiResult<Vec<entity::categories::Model>> {
        self.inner.create_batch(db, data).await
    }

    async fn delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.inner.delete_batch(db, ids).await
    }

    async fn exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        self.inner.exists(db, id).await
    }

    async fn count(&self, db: &DbConn) -> MijiResult<u64> {
        self.inner.count(db).await
    }

    async fn count_with_filter(&self, db: &DbConn, filter: CategoryFilter) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

impl CategoryService {
    pub async fn category_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::categories::Model> {
        let model = self.get_by_id(db, serial_num).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn category_create(
        &self,
        db: &DbConn,
        data: CategoryCreate,
    ) -> MijiResult<entity::categories::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn category_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: CategoryUpdate,
    ) -> MijiResult<entity::categories::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn category_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn category_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<CategoryFilter>,
    ) -> MijiResult<PagedResult<entity::categories::Model>> {
        let paged_result = self.list_paged(db, query).await?;

        // 对 paged_result.items 做本地化
        let mut local_items = Vec::with_capacity(paged_result.rows.len());
        for model in paged_result.rows {
            local_items.push(self.converter().model_with_local(model).await?);
        }

        Ok(PagedResult {
            rows: local_items,
            total_count: paged_result.total_count,
            total_pages: paged_result.total_pages,
            current_page: paged_result.current_page,
            page_size: paged_result.page_size,
        })
    }

    pub async fn category_list(&self, db: &DbConn) -> MijiResult<Vec<entity::categories::Model>> {
        let models = self.list(db).await?;
        // 对每个 Model 调用 model_with_local
        let mut local_models = Vec::with_capacity(models.len());
        for model in models {
            local_models.push(self.converter().model_with_local(model).await?);
        }
        Ok(local_models)
    }
}

pub fn get_category_service() -> CategoryService {
    CategoryService::new(
        CategoryConverter,
        CategoryHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
