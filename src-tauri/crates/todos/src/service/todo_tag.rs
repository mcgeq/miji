use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::{EmptyFilter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, DbConn, EntityTrait, prelude::async_trait::async_trait};

use crate::{
    dto::todo_tag::{TodoTagCreate, TodoTagUpdate},
    service::todo_tag_hooks::TodoTagHooks,
};

pub type TodoTagsFilter = EmptyFilter;

#[derive(Debug)]
pub struct TodoTagsConverter;

impl CrudConverter<entity::todo_tag::Entity, TodoTagCreate, TodoTagUpdate> for TodoTagsConverter {
    fn create_to_active_model(
        &self,
        data: TodoTagCreate,
    ) -> MijiResult<entity::todo_tag::ActiveModel> {
        entity::todo_tag::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::todo_tag::Model,
        data: TodoTagUpdate,
    ) -> MijiResult<entity::todo_tag::ActiveModel> {
        entity::todo_tag::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.todo_serial_num = ActiveValue::Set(model.todo_serial_num.clone());
                active_model.tag_serial_num = ActiveValue::Set(model.tag_serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::todo_tag::Model) -> String {
        format!("{}:{}", model.todo_serial_num, model.tag_serial_num)
    }

    fn table_name(&self) -> &'static str {
        "todo_tag"
    }
}

#[async_trait]
impl LocalizableConverter<entity::todo_tag::Model> for TodoTagsConverter {
    async fn model_with_local(
        &self,
        model: entity::todo_tag::Model,
    ) -> MijiResult<entity::todo_tag::Model> {
        Ok(model.to_local())
    }
}

impl TodoTagsConverter {
    pub fn parse_id(id: &str) -> (String, String) {
        let mut parts = id.splitn(2, ':');
        let category_name = parts.next().unwrap_or_default().to_string();
        let name = parts.next().unwrap_or_default().to_string();
        (category_name, name)
    }
}

// 待办事项-标签关联服务实现
pub struct TodoTagsService {
    inner: GenericCrudService<
        entity::todo_tag::Entity,
        TodoTagsFilter,
        TodoTagCreate,
        TodoTagUpdate,
        TodoTagsConverter,
        TodoTagHooks,
    >,
}

impl Default for TodoTagsService {
    fn default() -> Self {
        Self::new(
            TodoTagsConverter,
            TodoTagHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl TodoTagsService {
    pub fn new(
        converter: TodoTagsConverter,
        hooks: TodoTagHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for TodoTagsService {
    type Target = GenericCrudService<
        entity::todo_tag::Entity,
        TodoTagsFilter,
        TodoTagCreate,
        TodoTagUpdate,
        TodoTagsConverter,
        TodoTagHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TodoTagsService {
    pub async fn todo_tag_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::todo_tag::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::todo_tag::Entity::find().one(db).await?
        } else {
            let id_tuple = TodoTagsConverter::parse_id(&serial_num);
            Some(self.get_by_id(db, id_tuple).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(
                common::BusinessCode::NotFound,
                "todo_tag notfound".to_string(),
            )
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_tag_create(
        &self,
        db: &DbConn,
        data: TodoTagCreate,
    ) -> MijiResult<entity::todo_tag::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_tag_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: TodoTagUpdate,
    ) -> MijiResult<entity::todo_tag::Model> {
        let id_tuple = TodoTagsConverter::parse_id(&serial_num);
        let model = self.update(db, id_tuple, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_tag_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        let id_tuple = TodoTagsConverter::parse_id(&id);
        self.delete(db, id_tuple).await
    }

    pub async fn todo_tag_list(&self, db: &DbConn) -> MijiResult<Vec<entity::todo_tag::Model>> {
        let models = self.list(db).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_tag_list_with_filter(
        &self,
        db: &DbConn,
        filter: TodoTagsFilter,
    ) -> MijiResult<Vec<entity::todo_tag::Model>> {
        let models = self.list_with_filter(db, filter).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_tag_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<TodoTagsFilter>,
    ) -> MijiResult<PagedResult<entity::todo_tag::Model>> {
        self.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    pub async fn todo_tag_create_batch(
        &self,
        db: &DbConn,
        data: Vec<TodoTagCreate>,
    ) -> MijiResult<Vec<entity::todo_tag::Model>> {
        let models = self.create_batch(db, data).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_tag_exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        let id_tuple = TodoTagsConverter::parse_id(&id);
        self.exists(db, id_tuple).await
    }

    pub async fn todo_tag_count(&self, db: &DbConn) -> MijiResult<u64> {
        self.count(db).await
    }

    pub async fn todo_tag_count_with_filter(
        &self,
        db: &DbConn,
        filter: TodoTagsFilter,
    ) -> MijiResult<u64> {
        self.count_with_filter(db, filter).await
    }
}
