use std::sync::Arc;

use chrono::{DateTime, FixedOffset};
use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{ActiveValue, ColumnTrait, Condition, DbConn, prelude::async_trait::async_trait};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::period_daily_records::{PeriodDailyRecordCreate, PeriodDailyRecordUpdate},
    service::period_daily_records_hooks::PeriodDailyRecordHooks,
};

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodDailyRecordFilter {
    pub period_serial_num: Option<String>,
    pub date: Option<DateTime<FixedOffset>>,
    pub flow_level: Option<String>,
    pub exercise_intensity: Option<String>,
    pub sexual_activity: Option<bool>,
    pub contraception_method: Option<String>,
    pub diet: Option<String>,
    pub mood: Option<String>,
    pub water_intake: Option<i32>,
    pub sleep_hours: Option<i32>,
    pub notes: Option<String>,
}

impl Filter<entity::period_daily_records::Entity> for PeriodDailyRecordFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        let mut condition = Condition::all();

        if let Some(period_serial_num) = &self.period_serial_num {
            condition = condition
                .add(entity::period_daily_records::Column::PeriodSerialNum.eq(period_serial_num));
        }

        if let Some(date) = &self.date {
            condition = condition.add(entity::period_daily_records::Column::Date.eq(*date));
        }

        if let Some(flow_level) = &self.flow_level {
            condition =
                condition.add(entity::period_daily_records::Column::FlowLevel.eq(flow_level));
        }

        if let Some(exercise_intensity) = &self.exercise_intensity {
            condition = condition.add(
                entity::period_daily_records::Column::ExerciseIntensity.eq(exercise_intensity),
            );
        }

        if let Some(sexual_activity) = self.sexual_activity {
            condition = condition
                .add(entity::period_daily_records::Column::SexualActivity.eq(sexual_activity));
        }

        if let Some(contraception_method) = &self.contraception_method {
            condition = condition.add(
                entity::period_daily_records::Column::ContraceptionMethod.eq(contraception_method),
            );
        }

        if let Some(diet) = &self.diet {
            condition = condition.add(entity::period_daily_records::Column::Diet.eq(diet));
        }

        if let Some(mood) = &self.mood {
            condition = condition.add(entity::period_daily_records::Column::Mood.eq(mood));
        }

        if let Some(water_intake) = self.water_intake {
            condition =
                condition.add(entity::period_daily_records::Column::WaterIntake.eq(water_intake));
        }

        if let Some(sleep_hours) = self.sleep_hours {
            condition =
                condition.add(entity::period_daily_records::Column::SleepHours.eq(sleep_hours));
        }

        if let Some(notes) = &self.notes {
            condition = condition.add(entity::period_daily_records::Column::Notes.eq(notes));
        }

        condition
    }
}

#[derive(Debug)]
pub struct PeriodDailyRecordConverter;

impl
    CrudConverter<
        entity::period_daily_records::Entity,
        PeriodDailyRecordCreate,
        PeriodDailyRecordUpdate,
    > for PeriodDailyRecordConverter
{
    fn create_to_active_model(
        &self,
        data: PeriodDailyRecordCreate,
    ) -> MijiResult<entity::period_daily_records::ActiveModel> {
        entity::period_daily_records::ActiveModel::try_from(data)
            .map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::period_daily_records::Model,
        data: PeriodDailyRecordUpdate,
    ) -> MijiResult<entity::period_daily_records::ActiveModel> {
        entity::period_daily_records::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::period_daily_records::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "period_daily_records"
    }
}

impl PeriodDailyRecordConverter {
    pub async fn model_with_local(
        &self,
        model: entity::period_daily_records::Model,
    ) -> MijiResult<entity::period_daily_records::Model> {
        Ok(model.to_local())
    }
}

// 交易服务实现
pub struct PeriodDailyRecordService {
    inner: GenericCrudService<
        entity::period_daily_records::Entity,
        PeriodDailyRecordFilter,
        PeriodDailyRecordCreate,
        PeriodDailyRecordUpdate,
        PeriodDailyRecordConverter,
        PeriodDailyRecordHooks,
    >,
}

impl PeriodDailyRecordService {
    pub fn new(
        converter: PeriodDailyRecordConverter,
        hooks: PeriodDailyRecordHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for PeriodDailyRecordService {
    type Target = GenericCrudService<
        entity::period_daily_records::Entity,
        PeriodDailyRecordFilter,
        PeriodDailyRecordCreate,
        PeriodDailyRecordUpdate,
        PeriodDailyRecordConverter,
        PeriodDailyRecordHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

#[async_trait]
impl
    CrudService<
        entity::period_daily_records::Entity,
        PeriodDailyRecordFilter,
        PeriodDailyRecordCreate,
        PeriodDailyRecordUpdate,
    > for PeriodDailyRecordService
{
    async fn create(
        &self,
        db: &DbConn,
        data: PeriodDailyRecordCreate,
    ) -> MijiResult<entity::period_daily_records::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<entity::period_daily_records::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: PeriodDailyRecordUpdate,
    ) -> MijiResult<entity::period_daily_records::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::period_daily_records::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: PeriodDailyRecordFilter,
    ) -> MijiResult<Vec<entity::period_daily_records::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<PeriodDailyRecordFilter>,
    ) -> MijiResult<PagedResult<entity::period_daily_records::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<PeriodDailyRecordCreate>,
    ) -> MijiResult<Vec<entity::period_daily_records::Model>> {
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
        filter: PeriodDailyRecordFilter,
    ) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

impl PeriodDailyRecordService {
    pub async fn period_daily_record_create(
        &self,
        db: &DbConn,
        data: PeriodDailyRecordCreate,
    ) -> MijiResult<entity::period_daily_records::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_daily_record_get(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<entity::period_daily_records::Model> {
        let model = self.get_by_id(db, id).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_daily_record_update(
        &self,
        db: &DbConn,
        id: String,
        data: PeriodDailyRecordUpdate,
    ) -> MijiResult<entity::period_daily_records::Model> {
        let model = self.update(db, id, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn period_daily_record_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn period_daily_record_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<PeriodDailyRecordFilter>,
    ) -> MijiResult<PagedResult<entity::period_daily_records::Model>> {
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

pub fn get_period_daily_record_service() -> PeriodDailyRecordService {
    PeriodDailyRecordService::new(
        PeriodDailyRecordConverter,
        PeriodDailyRecordHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
