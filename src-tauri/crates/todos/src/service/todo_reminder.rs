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
    dto::todo_reminder::{ReminderCreate, ReminderUpdate},
    service::todo_reminder_hooks::TodoReminderHooks,
};

pub type TodoReminderFilter = EmptyFilter;

#[derive(Debug)]
pub struct TodoReminderConverter;

impl CrudConverter<entity::reminder::Entity, ReminderCreate, ReminderUpdate>
    for TodoReminderConverter
{
    fn create_to_active_model(
        &self,
        data: ReminderCreate,
    ) -> MijiResult<entity::reminder::ActiveModel> {
        entity::reminder::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::reminder::Model,
        data: ReminderUpdate,
    ) -> MijiResult<entity::reminder::ActiveModel> {
        entity::reminder::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::reminder::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "reminder"
    }
}

#[async_trait]
impl LocalizableConverter<entity::reminder::Model> for TodoReminderConverter {
    async fn model_with_local(
        &self,
        model: entity::reminder::Model,
    ) -> MijiResult<entity::reminder::Model> {
        Ok(model.to_local())
    }
}

// 待办事项提醒服务实现
pub struct TodoRemindersService {
    inner: GenericCrudService<
        entity::reminder::Entity,
        TodoReminderFilter,
        ReminderCreate,
        ReminderUpdate,
        TodoReminderConverter,
        TodoReminderHooks,
    >,
}

impl Default for TodoRemindersService {
    fn default() -> Self {
        Self::new(
            TodoReminderConverter,
            TodoReminderHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl TodoRemindersService {
    pub fn new(
        converter: TodoReminderConverter,
        hooks: TodoReminderHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for TodoRemindersService {
    type Target = GenericCrudService<
        entity::reminder::Entity,
        TodoReminderFilter,
        ReminderCreate,
        ReminderUpdate,
        TodoReminderConverter,
        TodoReminderHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TodoRemindersService {
    pub async fn reminder_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::reminder::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::reminder::Entity::find().one(db).await?
        } else {
            Some(self.get_by_id(db, serial_num).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(
                common::BusinessCode::NotFound,
                "reminder notfound".to_string(),
            )
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn reminder_create(
        &self,
        db: &DbConn,
        data: ReminderCreate,
    ) -> MijiResult<entity::reminder::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn reminder_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: ReminderUpdate,
    ) -> MijiResult<entity::reminder::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn reminder_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn reminder_list(&self, db: &DbConn) -> MijiResult<Vec<entity::reminder::Model>> {
        let models = self.list(db).await?;
        self.converter().localize_models(models).await
    }

    pub async fn reminder_list_with_filter(
        &self,
        db: &DbConn,
        filter: TodoReminderFilter,
    ) -> MijiResult<Vec<entity::reminder::Model>> {
        let models = self.list_with_filter(db, filter).await?;
        self.converter().localize_models(models).await
    }

    pub async fn reminder_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<TodoReminderFilter>,
    ) -> MijiResult<PagedResult<entity::reminder::Model>> {
        self.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    pub async fn reminder_create_batch(
        &self,
        db: &DbConn,
        data: Vec<ReminderCreate>,
    ) -> MijiResult<Vec<entity::reminder::Model>> {
        let models = self.create_batch(db, data).await?;
        self.converter().localize_models(models).await
    }

    pub async fn reminder_delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.delete_batch(db, ids).await
    }

    pub async fn reminder_exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        self.exists(db, id).await
    }

    pub async fn reminder_count(&self, db: &DbConn) -> MijiResult<u64> {
        self.count(db).await
    }

    pub async fn reminder_count_with_filter(
        &self,
        db: &DbConn,
        filter: TodoReminderFilter,
    ) -> MijiResult<u64> {
        self.count_with_filter(db, filter).await
    }
}
