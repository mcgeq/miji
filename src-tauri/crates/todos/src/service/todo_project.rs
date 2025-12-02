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
    dto::todo_project::{TodoProjectCreate, TodoProjectUpdate},
    service::todo_project_hooks::TodoProjectHooks,
};

pub type TodoProjectFilter = EmptyFilter;

#[derive(Debug)]
pub struct TodoProjectsConverter;

impl CrudConverter<entity::todo_project::Entity, TodoProjectCreate, TodoProjectUpdate>
    for TodoProjectsConverter
{
    fn create_to_active_model(
        &self,
        data: TodoProjectCreate,
    ) -> MijiResult<entity::todo_project::ActiveModel> {
        entity::todo_project::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::todo_project::Model,
        data: TodoProjectUpdate,
    ) -> MijiResult<entity::todo_project::ActiveModel> {
        entity::todo_project::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.todo_serial_num = ActiveValue::Set(model.todo_serial_num.clone());
                active_model.project_serial_num =
                    ActiveValue::Set(model.project_serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::todo_project::Model) -> String {
        format!("{}:{}", model.todo_serial_num, model.project_serial_num)
    }

    fn table_name(&self) -> &'static str {
        "todo_project"
    }
}

#[async_trait]
impl LocalizableConverter<entity::todo_project::Model> for TodoProjectsConverter {
    async fn model_with_local(
        &self,
        model: entity::todo_project::Model,
    ) -> MijiResult<entity::todo_project::Model> {
        Ok(model.to_local())
    }
}

impl TodoProjectsConverter {
    pub fn parse_id(id: &str) -> (String, String) {
        let mut parts = id.splitn(2, ':');
        let category_name = parts.next().unwrap_or_default().to_string();
        let name = parts.next().unwrap_or_default().to_string();
        (category_name, name)
    }
}

// 待办事项-项目关联服务实现
pub struct TodoProjectsService {
    inner: GenericCrudService<
        entity::todo_project::Entity,
        TodoProjectFilter,
        TodoProjectCreate,
        TodoProjectUpdate,
        TodoProjectsConverter,
        TodoProjectHooks,
    >,
}

impl Default for TodoProjectsService {
    fn default() -> Self {
        Self::new(
            TodoProjectsConverter,
            TodoProjectHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl TodoProjectsService {
    pub fn new(
        converter: TodoProjectsConverter,
        hooks: TodoProjectHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for TodoProjectsService {
    type Target = GenericCrudService<
        entity::todo_project::Entity,
        TodoProjectFilter,
        TodoProjectCreate,
        TodoProjectUpdate,
        TodoProjectsConverter,
        TodoProjectHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TodoProjectsService {
    pub async fn todo_project_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::todo_project::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::todo_project::Entity::find().one(db).await?
        } else {
            let id_tuple = TodoProjectsConverter::parse_id(&serial_num);
            Some(self.get_by_id(db, id_tuple).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(
                common::BusinessCode::NotFound,
                "todo_project notfound".to_string(),
            )
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_project_create(
        &self,
        db: &DbConn,
        data: TodoProjectCreate,
    ) -> MijiResult<entity::todo_project::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_project_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: TodoProjectUpdate,
    ) -> MijiResult<entity::todo_project::Model> {
        let id_tuple = TodoProjectsConverter::parse_id(&serial_num);
        let model = self.update(db, id_tuple, data).await?;
        self.converter().model_with_local(model).await
    }
    pub async fn todo_project_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        let id_tuple = TodoProjectsConverter::parse_id(&id);
        self.delete(db, id_tuple).await
    }

    pub async fn todo_project_list(
        &self,
        db: &DbConn,
    ) -> MijiResult<Vec<entity::todo_project::Model>> {
        let models = self.list(db).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_project_list_with_filter(
        &self,
        db: &DbConn,
        filter: TodoProjectFilter,
    ) -> MijiResult<Vec<entity::todo_project::Model>> {
        let models = self.list_with_filter(db, filter).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_project_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<TodoProjectFilter>,
    ) -> MijiResult<PagedResult<entity::todo_project::Model>> {
        self.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    pub async fn todo_project_create_batch(
        &self,
        db: &DbConn,
        data: Vec<TodoProjectCreate>,
    ) -> MijiResult<Vec<entity::todo_project::Model>> {
        let models = self.create_batch(db, data).await?;
        self.converter().localize_models(models).await
    }
}
