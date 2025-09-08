use std::sync::Arc;

use chrono::{DateTime, FixedOffset};
use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use macros::add_filter_condition;
use sea_orm::{ActiveValue, ColumnTrait, Condition, DbConn, prelude::async_trait::async_trait};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::bil_reminder::{BilReminderCreate, BilReminderUpdate},
    services::bil_reminder_hooks::BilReminderHooks,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FilterOp {
    Eq,
    Gt,
    Gte,
    Lt,
    Lte,
    Ne,
    Like,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BilReminderFilters {
    pub name: Option<String>,
    pub category: Option<String>,
    pub enabled: Option<bool>,
    pub r#type: Option<String>,
    pub currency: Option<String>,
    pub due_at: Option<DateTime<FixedOffset>>,
    pub bill_date: Option<DateTime<FixedOffset>>,
    pub remind_date: Option<DateTime<FixedOffset>>,
    pub repeat_period: Option<String>,
    pub is_paid: Option<bool>,
    pub priority: Option<String>,
    pub advance_value: Option<i32>,
    pub advance_unit: Option<String>,
    pub related_transaction_serial_num: Option<String>,
    pub color: Option<String>,
    pub is_deleted: Option<bool>,
}

// Converter struct
#[derive(Debug)]
pub struct BilReminderConverter;

// 交易服务实现
pub struct BilReminderService {
    inner: GenericCrudService<
        entity::bil_reminder::Entity,
        BilReminderFilters,
        BilReminderCreate,
        BilReminderUpdate,
        BilReminderConverter,
        BilReminderHooks,
    >,
}

impl BilReminderService {
    pub fn new(
        converter: BilReminderConverter,
        hooks: BilReminderHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for BilReminderService {
    type Target = GenericCrudService<
        entity::bil_reminder::Entity,
        BilReminderFilters,
        BilReminderCreate,
        BilReminderUpdate,
        BilReminderConverter,
        BilReminderHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl CrudConverter<entity::bil_reminder::Entity, BilReminderCreate, BilReminderUpdate>
    for BilReminderConverter
{
    fn create_to_active_model(
        &self,
        data: BilReminderCreate,
    ) -> common::error::MijiResult<
        <entity::bil_reminder::Entity as sea_orm::EntityTrait>::ActiveModel,
    > {
        entity::bil_reminder::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::bil_reminder::Model,
        data: BilReminderUpdate,
    ) -> MijiResult<entity::bil_reminder::ActiveModel> {
        entity::bil_reminder::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::bil_reminder::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "bil_reminder"
    }
}

impl Filter<entity::bil_reminder::Entity> for BilReminderFilters {
    fn to_condition(&self) -> sea_orm::Condition {
        let mut condition = Condition::all();
        add_filter_condition!(
            condition,
            self,
            name,
            entity::bil_reminder::Column::Name,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            category,
            entity::bil_reminder::Column::Category,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            enabled,
            entity::bil_reminder::Column::Enabled,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            r#type,
            entity::bil_reminder::Column::Type,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            currency,
            entity::bil_reminder::Column::Currency,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            due_at,
            entity::bil_reminder::Column::DueAt,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            bill_date,
            entity::bil_reminder::Column::BillDate,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            remind_date,
            entity::bil_reminder::Column::RemindDate,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            repeat_period,
            entity::bil_reminder::Column::RepeatPeriod,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            is_paid,
            entity::bil_reminder::Column::IsPaid,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            priority,
            entity::bil_reminder::Column::Priority,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            advance_value,
            entity::bil_reminder::Column::AdvanceValue,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            advance_unit,
            entity::bil_reminder::Column::AdvanceUnit,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            related_transaction_serial_num,
            entity::bil_reminder::Column::RelatedTransactionSerialNum,
            FilterOp::Eq
        );
        add_filter_condition!(
            condition,
            self,
            is_deleted,
            entity::bil_reminder::Column::IsDeleted,
            FilterOp::Eq
        );
        condition
    }
}

#[async_trait]
impl
    CrudService<
        entity::bil_reminder::Entity,
        BilReminderFilters,
        BilReminderCreate,
        BilReminderUpdate,
    > for BilReminderService
{
    async fn create(
        &self,
        db: &DbConn,
        data: BilReminderCreate,
    ) -> MijiResult<entity::bil_reminder::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(&self, db: &DbConn, id: String) -> MijiResult<entity::bil_reminder::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: BilReminderUpdate,
    ) -> MijiResult<entity::bil_reminder::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::bil_reminder::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: BilReminderFilters,
    ) -> MijiResult<Vec<entity::bil_reminder::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<BilReminderFilters>,
    ) -> MijiResult<PagedResult<entity::bil_reminder::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<BilReminderCreate>,
    ) -> MijiResult<Vec<entity::bil_reminder::Model>> {
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

    async fn count_with_filter(&self, db: &DbConn, filter: BilReminderFilters) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

pub fn get_bil_reminder_service() -> BilReminderService {
    BilReminderService::new(
        BilReminderConverter,
        BilReminderHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
