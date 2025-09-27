use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, Condition, DbConn, EntityTrait};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::todo::{TodoCreate, TodoUpdate},
    service::todo_hooks::TodoHooks,
};

#[derive(Debug, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodosFilter {}

impl Filter<entity::todo::Entity> for TodosFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        Condition::all()
    }
}

#[derive(Debug)]
pub struct TodosConverter;

impl CrudConverter<entity::todo::Entity, TodoCreate, TodoUpdate> for TodosConverter {
    fn create_to_active_model(&self, data: TodoCreate) -> MijiResult<entity::todo::ActiveModel> {
        entity::todo::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::todo::Model,
        data: TodoUpdate,
    ) -> MijiResult<entity::todo::ActiveModel> {
        entity::todo::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::todo::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "todo"
    }
}

impl TodosConverter {
    pub async fn model_with_local(
        &self,
        model: entity::todo::Model,
    ) -> MijiResult<entity::todo::Model> {
        Ok(model.to_local())
    }

    pub async fn localize_models(
        &self,
        models: Vec<entity::todo::Model>,
    ) -> MijiResult<Vec<entity::todo::Model>> {
        futures::future::try_join_all(models.into_iter().map(|m| self.model_with_local(m))).await
    }
}

// 交易服务实现
pub struct TodosService {
    inner: GenericCrudService<
        entity::todo::Entity,
        TodosFilter,
        TodoCreate,
        TodoUpdate,
        TodosConverter,
        TodoHooks,
    >,
}

impl TodosService {
    pub fn new(
        converter: TodosConverter,
        hooks: TodoHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for TodosService {
    type Target = GenericCrudService<
        entity::todo::Entity,
        TodosFilter,
        TodoCreate,
        TodoUpdate,
        TodosConverter,
        TodoHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TodosService {
    pub async fn todo_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::todo::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::todo::Entity::find().one(db).await?
        } else {
            Some(self.get_by_id(db, serial_num).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(common::BusinessCode::NotFound, "todo notfound".to_string())
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_create(
        &self,
        db: &DbConn,
        data: TodoCreate,
    ) -> MijiResult<entity::todo::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: TodoUpdate,
    ) -> MijiResult<entity::todo::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn todo_list(&self, db: &DbConn) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.list(db).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_list_with_filter(
        &self,
        db: &DbConn,
        filter: TodosFilter,
    ) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.list_with_filter(db, filter).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<TodosFilter>,
    ) -> MijiResult<PagedResult<entity::todo::Model>> {
        let paged = self.list_paged(db, query).await?;
        let models = self.converter().localize_models(paged.rows).await?;
        Ok(PagedResult {
            rows: models,
            total_count: paged.total_count,
            current_page: paged.current_page,
            page_size: paged.page_size,
            total_pages: paged.total_pages,
        })
    }

    pub async fn todo_create_batch(
        &self,
        db: &DbConn,
        data: Vec<TodoCreate>,
    ) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.create_batch(db, data).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.delete_batch(db, ids).await
    }

    pub async fn todo_exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        self.exists(db, id).await
    }

    pub async fn todo_count(&self, db: &DbConn) -> MijiResult<u64> {
        self.count(db).await
    }

    pub async fn todo_count_with_filter(
        &self,
        db: &DbConn,
        filter: TodosFilter,
    ) -> MijiResult<u64> {
        self.count_with_filter(db, filter).await
    }
}

pub fn get_todos_service() -> TodosService {
    TodosService::new(
        TodosConverter,
        TodoHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
