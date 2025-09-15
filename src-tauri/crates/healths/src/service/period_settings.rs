use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, Condition, DbConn, EntityTrait, prelude::async_trait::async_trait};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::period_settings::{PeriodSettingsCreate, PeriodSettingsUpdate},
    service::period_settings_hooks::PeriodSettingsHooks,
};

#[derive(Debug, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodSettingsFilter {}

impl Filter<entity::period_settings::Entity> for PeriodSettingsFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        Condition::all()
    }
}

#[derive(Debug)]
pub struct PeriodSettingsConverter;

impl CrudConverter<entity::period_settings::Entity, PeriodSettingsCreate, PeriodSettingsUpdate>
    for PeriodSettingsConverter
{
    fn create_to_active_model(
        &self,
        data: PeriodSettingsCreate,
    ) -> MijiResult<entity::period_settings::ActiveModel> {
        entity::period_settings::ActiveModel::try_from(data)
            .map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::period_settings::Model,
        data: PeriodSettingsUpdate,
    ) -> MijiResult<entity::period_settings::ActiveModel> {
        entity::period_settings::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::period_settings::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "period_settings"
    }
}

impl PeriodSettingsConverter {
    pub async fn model_with_local(
        &self,
        model: entity::period_settings::Model,
    ) -> MijiResult<entity::period_settings::Model> {
        Ok(model.to_local())
    }
}

// 交易服务实现
pub struct PeriodSettingsService {
    inner: GenericCrudService<
        entity::period_settings::Entity,
        PeriodSettingsFilter,
        PeriodSettingsCreate,
        PeriodSettingsUpdate,
        PeriodSettingsConverter,
        PeriodSettingsHooks,
    >,
}

impl PeriodSettingsService {
    pub fn new(
        converter: PeriodSettingsConverter,
        hooks: PeriodSettingsHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for PeriodSettingsService {
    type Target = GenericCrudService<
        entity::period_settings::Entity,
        PeriodSettingsFilter,
        PeriodSettingsCreate,
        PeriodSettingsUpdate,
        PeriodSettingsConverter,
        PeriodSettingsHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

#[async_trait]
impl
    CrudService<
        entity::period_settings::Entity,
        PeriodSettingsFilter,
        PeriodSettingsCreate,
        PeriodSettingsUpdate,
    > for PeriodSettingsService
{
    async fn create(
        &self,
        db: &DbConn,
        data: PeriodSettingsCreate,
    ) -> MijiResult<entity::period_settings::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<entity::period_settings::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: PeriodSettingsUpdate,
    ) -> MijiResult<entity::period_settings::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::period_settings::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: PeriodSettingsFilter,
    ) -> MijiResult<Vec<entity::period_settings::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<PeriodSettingsFilter>,
    ) -> MijiResult<PagedResult<entity::period_settings::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<PeriodSettingsCreate>,
    ) -> MijiResult<Vec<entity::period_settings::Model>> {
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

    async fn count_with_filter(
        &self,
        db: &DbConn,
        filter: PeriodSettingsFilter,
    ) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

impl PeriodSettingsService {
    pub async fn period_settings_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::period_settings::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::period_settings::Entity::find().one(db).await?
        } else {
            Some(self.get_by_id(db, serial_num).await?)
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
        data: PeriodSettingsCreate,
    ) -> MijiResult<entity::period_settings::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_settings_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: PeriodSettingsUpdate,
    ) -> MijiResult<entity::period_settings::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }
}

pub fn get_settings_service() -> PeriodSettingsService {
    PeriodSettingsService::new(
        PeriodSettingsConverter,
        PeriodSettingsHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
