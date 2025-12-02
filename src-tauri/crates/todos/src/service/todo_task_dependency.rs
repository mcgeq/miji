use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::EmptyFilter,
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, DbConn, EntityTrait, prelude::async_trait::async_trait};

use crate::{
    dto::todo_task_dependency::{TaskDependencyCreate, TaskDependencyUpdate},
    service::todo_task_dependency_hooks::TodoTaskDependencyHooks,
};

pub type TodoTaskDependencyFilter = EmptyFilter;

#[derive(Debug)]
pub struct TodoTaskDependencyConverter;

impl CrudConverter<entity::task_dependency::Entity, TaskDependencyCreate, TaskDependencyUpdate>
    for TodoTaskDependencyConverter
{
    fn create_to_active_model(
        &self,
        data: TaskDependencyCreate,
    ) -> MijiResult<entity::task_dependency::ActiveModel> {
        entity::task_dependency::ActiveModel::try_from(data)
            .map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::task_dependency::Model,
        data: TaskDependencyUpdate,
    ) -> MijiResult<entity::task_dependency::ActiveModel> {
        entity::task_dependency::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.task_serial_num = ActiveValue::Set(model.task_serial_num.clone());
                active_model.depends_on_task_serial_num =
                    ActiveValue::Set(model.depends_on_task_serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::task_dependency::Model) -> String {
        format!(
            "{}:{}",
            model.task_serial_num, model.depends_on_task_serial_num
        )
    }

    fn table_name(&self) -> &'static str {
        "task_dependency"
    }
}

#[async_trait]
impl LocalizableConverter<entity::task_dependency::Model> for TodoTaskDependencyConverter {
    async fn model_with_local(
        &self,
        model: entity::task_dependency::Model,
    ) -> MijiResult<entity::task_dependency::Model> {
        Ok(model.to_local())
    }
}

impl TodoTaskDependencyConverter {
    pub fn parse_id(id: &str) -> (String, String) {
        let mut parts = id.splitn(2, ':');
        let category_name = parts.next().unwrap_or_default().to_string();
        let name = parts.next().unwrap_or_default().to_string();
        (category_name, name)
    }
}

// 任务依赖服务实现
pub struct TodoTaskDependencyService {
    inner: GenericCrudService<
        entity::task_dependency::Entity,
        TodoTaskDependencyFilter,
        TaskDependencyCreate,
        TaskDependencyUpdate,
        TodoTaskDependencyConverter,
        TodoTaskDependencyHooks,
    >,
}

impl Default for TodoTaskDependencyService {
    fn default() -> Self {
        Self::new(
            TodoTaskDependencyConverter,
            TodoTaskDependencyHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl TodoTaskDependencyService {
    pub fn new(
        converter: TodoTaskDependencyConverter,
        hooks: TodoTaskDependencyHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for TodoTaskDependencyService {
    type Target = GenericCrudService<
        entity::task_dependency::Entity,
        TodoTaskDependencyFilter,
        TaskDependencyCreate,
        TaskDependencyUpdate,
        TodoTaskDependencyConverter,
        TodoTaskDependencyHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TodoTaskDependencyService {
    pub async fn task_dependency_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::task_dependency::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::task_dependency::Entity::find().one(db).await?
        } else {
            let id_tuple = TodoTaskDependencyConverter::parse_id(&serial_num);
            Some(self.get_by_id(db, id_tuple).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(
                common::BusinessCode::NotFound,
                "task_dependency not found".to_string(),
            )
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn task_dependency_create(
        &self,
        db: &DbConn,
        data: TaskDependencyCreate,
    ) -> MijiResult<entity::task_dependency::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn task_dependency_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: TaskDependencyUpdate,
    ) -> MijiResult<entity::task_dependency::Model> {
        let id_tuple = TodoTaskDependencyConverter::parse_id(&serial_num);
        let model = self.update(db, id_tuple, data).await?;
        self.converter().model_with_local(model).await
    }
}
