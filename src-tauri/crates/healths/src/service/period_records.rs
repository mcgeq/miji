use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{DateRange, Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, ColumnTrait, Condition, DbConn, prelude::async_trait::async_trait};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::period_records::{PeriodRecordsCreate, PeriodRecordsUpdate},
    service::period_records_hooks::PeriodRecordsHooks,
};

#[derive(Debug, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodRecordFilter {
    pub notes: Option<String>,
    pub start_date: Option<DateRange>,
    pub end_date: Option<DateRange>,
}

impl Filter<entity::period_records::Entity> for PeriodRecordFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        let mut condition = Condition::all();
        if let Some(notes) = &self.notes {
            condition = condition.add(entity::period_records::Column::Notes.like(notes));
        }
        if let Some(start_date) = &self.start_date {
            if let Some(start) = &start_date.start {
                condition = condition.add(entity::budget::Column::StartDate.gte(start));
            }
            if let Some(end) = &start_date.end {
                condition = condition.add(entity::budget::Column::StartDate.lte(end))
            }
        }

        // End Date (assuming ISO 8601 format)
        if let Some(end_date) = &self.end_date {
            if let Some(start) = &end_date.start {
                condition = condition.add(entity::budget::Column::EndDate.gte(start));
            }
            if let Some(end) = &end_date.end {
                condition = condition.add(entity::budget::Column::EndDate.lte(end))
            }
        }
        condition
    }
}

#[derive(Debug)]
pub struct PeriodRecordConverter;

impl CrudConverter<entity::period_records::Entity, PeriodRecordsCreate, PeriodRecordsUpdate>
    for PeriodRecordConverter
{
    fn create_to_active_model(
        &self,
        data: PeriodRecordsCreate,
    ) -> MijiResult<<entity::period_records::Entity as sea_orm::EntityTrait>::ActiveModel> {
        entity::period_records::ActiveModel::try_from(data)
            .map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::period_records::Model,
        data: PeriodRecordsUpdate,
    ) -> MijiResult<entity::period_records::ActiveModel> {
        entity::period_records::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::period_records::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "period_records"
    }
}

impl PeriodRecordConverter {
    pub async fn model_with_local(
        &self,
        model: entity::period_records::Model,
    ) -> MijiResult<entity::period_records::Model> {
        Ok(model.to_local())
    }
}

// 交易服务实现
pub struct PeriodRecordService {
    inner: GenericCrudService<
        entity::period_records::Entity,
        PeriodRecordFilter,
        PeriodRecordsCreate,
        PeriodRecordsUpdate,
        PeriodRecordConverter,
        PeriodRecordsHooks,
    >,
}

impl PeriodRecordService {
    pub fn new(
        converter: PeriodRecordConverter,
        hooks: PeriodRecordsHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for PeriodRecordService {
    type Target = GenericCrudService<
        entity::period_records::Entity,
        PeriodRecordFilter,
        PeriodRecordsCreate,
        PeriodRecordsUpdate,
        PeriodRecordConverter,
        PeriodRecordsHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

#[async_trait]
impl
    CrudService<
        entity::period_records::Entity,
        PeriodRecordFilter,
        PeriodRecordsCreate,
        PeriodRecordsUpdate,
    > for PeriodRecordService
{
    async fn create(
        &self,
        db: &DbConn,
        data: PeriodRecordsCreate,
    ) -> MijiResult<entity::period_records::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<entity::period_records::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: PeriodRecordsUpdate,
    ) -> MijiResult<entity::period_records::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::period_records::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: PeriodRecordFilter,
    ) -> MijiResult<Vec<entity::period_records::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<PeriodRecordFilter>,
    ) -> MijiResult<PagedResult<entity::period_records::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<PeriodRecordsCreate>,
    ) -> MijiResult<Vec<entity::period_records::Model>> {
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

    async fn count_with_filter(&self, db: &DbConn, filter: PeriodRecordFilter) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

impl PeriodRecordService {
    pub async fn period_record_create(
        &self,
        db: &DbConn,
        data: PeriodRecordsCreate,
    ) -> MijiResult<entity::period_records::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_record_get(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<entity::period_records::Model> {
        let model = self.get_by_id(db, id).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_record_update(
        &self,
        db: &DbConn,
        id: String,
        data: PeriodRecordsUpdate,
    ) -> MijiResult<entity::period_records::Model> {
        let model = self.update(db, id, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_record_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn period_record_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<PeriodRecordFilter>,
    ) -> MijiResult<PagedResult<entity::period_records::Model>> {
        let paged = self.list_paged(db, query).await?;
        let mut rows_with_relations = Vec::with_capacity(paged.rows.len());
        for m in paged.rows {
            let tx_with_rel = self.inner.converter().model_with_local(m).await?;
            rows_with_relations.push(tx_with_rel);
        }

        Ok(PagedResult {
            rows: rows_with_relations,
            total_count: paged.total_count,
            current_page: paged.current_page,
            page_size: paged.page_size,
            total_pages: paged.total_pages,
        })
    }
}

pub fn get_period_record_service() -> PeriodRecordService {
    PeriodRecordService::new(
        PeriodRecordConverter,
        PeriodRecordsHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
