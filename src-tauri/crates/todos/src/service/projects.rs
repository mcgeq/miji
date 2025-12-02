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
    dto::projects::{ProjectCreate, ProjectUpdate},
    service::projects_hooks::ProjectHooks,
};

pub type ProjectsFilter = EmptyFilter;

#[derive(Debug)]
pub struct ProjectConverter;

impl CrudConverter<entity::project::Entity, ProjectCreate, ProjectUpdate> for ProjectConverter {
    fn create_to_active_model(
        &self,
        data: ProjectCreate,
    ) -> MijiResult<entity::project::ActiveModel> {
        entity::project::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::project::Model,
        data: ProjectUpdate,
    ) -> MijiResult<entity::project::ActiveModel> {
        entity::project::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::project::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "project"
    }
}

#[async_trait]
impl LocalizableConverter<entity::project::Model> for ProjectConverter {
    async fn model_with_local(
        &self,
        model: entity::project::Model,
    ) -> MijiResult<entity::project::Model> {
        Ok(model.to_local())
    }
}

// 项目服务实现
pub struct ProjectsService {
    inner: GenericCrudService<
        entity::project::Entity,
        ProjectsFilter,
        ProjectCreate,
        ProjectUpdate,
        ProjectConverter,
        ProjectHooks,
    >,
}

impl Default for ProjectsService {
    fn default() -> Self {
        Self::new(
            ProjectConverter,
            ProjectHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl ProjectsService {
    pub fn new(
        converter: ProjectConverter,
        hooks: ProjectHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for ProjectsService {
    type Target = GenericCrudService<
        entity::project::Entity,
        ProjectsFilter,
        ProjectCreate,
        ProjectUpdate,
        ProjectConverter,
        ProjectHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl ProjectsService {
    pub async fn project_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::project::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::project::Entity::find().one(db).await?
        } else {
            Some(self.get_by_id(db, serial_num).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(
                common::BusinessCode::NotFound,
                "project notfound".to_string(),
            )
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn project_create(
        &self,
        db: &DbConn,
        data: ProjectCreate,
    ) -> MijiResult<entity::project::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn project_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: ProjectUpdate,
    ) -> MijiResult<entity::project::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn project_list(&self, db: &DbConn) -> MijiResult<Vec<entity::project::Model>> {
        let models = self.list(db).await?;
        self.converter().localize_models(models).await
    }

    pub async fn project_list_with_filter(
        &self,
        db: &DbConn,
        filter: ProjectsFilter,
    ) -> MijiResult<Vec<entity::project::Model>> {
        let models = self.list_with_filter(db, filter).await?;
        self.converter().localize_models(models).await
    }

    pub async fn project_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<ProjectsFilter>,
    ) -> MijiResult<PagedResult<entity::project::Model>> {
        self.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    pub async fn project_create_batch(
        &self,
        db: &DbConn,
        data: Vec<ProjectCreate>,
    ) -> MijiResult<Vec<entity::project::Model>> {
        let models = self.create_batch(db, data).await?;
        self.converter().localize_models(models).await
    }

    pub async fn project_delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.delete_batch(db, ids).await
    }

    pub async fn project_exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        self.exists(db, id).await
    }

    pub async fn project_count(&self, db: &DbConn) -> MijiResult<u64> {
        self.count(db).await
    }

    pub async fn project_count_with_filter(
        &self,
        db: &DbConn,
        filter: ProjectsFilter,
    ) -> MijiResult<u64> {
        self.count_with_filter(db, filter).await
    }
}
