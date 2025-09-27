use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::Filter,
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, Condition, DbConn, EntityTrait};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::todo_task_dependency::{TaskDependencyCreate, TaskDependencyUpdate},
    service::todo_task_dependency_hooks::TodoTaskDependencyHooks,
};

#[derive(Debug, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodoTaskDependencyFilter {}

impl Filter<entity::task_dependency::Entity> for TodoTaskDependencyFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        Condition::all()
    }
}

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
        "period_settings"
    }
}

impl TodoTaskDependencyConverter {
    pub async fn model_with_local(
        &self,
        model: entity::task_dependency::Model,
    ) -> MijiResult<entity::task_dependency::Model> {
        Ok(model.to_local())
    }

    pub async fn localize_models(
        &self,
        models: Vec<entity::task_dependency::Model>,
    ) -> MijiResult<Vec<entity::task_dependency::Model>> {
        futures::future::try_join_all(models.into_iter().map(|m| self.model_with_local(m))).await
    }

    pub fn parse_id(id: &str) -> (String, String) {
        let mut parts = id.splitn(2, ':');
        let category_name = parts.next().unwrap_or_default().to_string();
        let name = parts.next().unwrap_or_default().to_string();
        (category_name, name)
    }
}

// 交易服务实现
pub struct PeriodSettingsService {
    inner: GenericCrudService<
        entity::task_dependency::Entity,
        TodoTaskDependencyFilter,
        TaskDependencyCreate,
        TaskDependencyUpdate,
        TodoTaskDependencyConverter,
        TodoTaskDependencyHooks,
    >,
}

impl PeriodSettingsService {
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

impl std::ops::Deref for PeriodSettingsService {
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

impl PeriodSettingsService {
    pub async fn period_settings_get(
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
                "period_settings notfound".to_string(),
            )
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_settings_create(
        &self,
        db: &DbConn,
        data: TaskDependencyCreate,
    ) -> MijiResult<entity::task_dependency::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_settings_update(
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

pub fn get_settings_service() -> PeriodSettingsService {
    PeriodSettingsService::new(
        TodoTaskDependencyConverter,
        TodoTaskDependencyHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
