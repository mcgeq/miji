use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{DateRange, Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::{
    ActiveValue, ColumnTrait, Condition, DbConn,
    prelude::{Decimal, async_trait::async_trait},
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use validator::Validate;

use crate::{
    dto::budget::{BudgetCreate, BudgetUpdate, BudgetWithAccount},
    services::{
        account::get_account_service, budget_hook::BudgetHooks, currency::get_currency_service,
    },
};

// Filter struct
#[derive(Debug, Validate, Serialize, Deserialize)]
pub struct BudgetFilter {
    pub account_serial_num: Option<String>,
    #[validate(length(min = 2, max = 20))]
    pub name: Option<String>,
    pub category: Option<String>,
    pub amount: Option<Decimal>,
    pub repeat_period: Option<String>,
    pub start_date: Option<DateRange>,
    pub end_date: Option<DateRange>,
    pub used_amount: Option<Decimal>,
    pub is_active: Option<bool>,
    pub alert_enabled: Option<bool>,
    pub alert_threshold: Option<String>,
}

impl Filter<entity::budget::Entity> for BudgetFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        let mut condition = Condition::all();
        if let Some(account_serial_num) = &self.account_serial_num {
            condition =
                condition.add(entity::budget::Column::AccountSerialNum.eq(account_serial_num));
        }

        if let Some(name) = &self.name {
            condition = condition.add(entity::budget::Column::Name.eq(name));
        }

        // Amount
        if let Some(amount) = self.amount {
            condition = condition.add(entity::budget::Column::Amount.eq(amount));
        }

        // Repeat Period
        if let Some(repeat_period) = &self.repeat_period {
            condition = condition.add(entity::budget::Column::RepeatPeriod.eq(repeat_period));
        }

        // Start Date (assuming ISO 8601 format)
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

        // Used Amount
        if let Some(used_amount) = self.used_amount {
            condition = condition.add(entity::budget::Column::UsedAmount.eq(used_amount));
        }

        // Active Status
        if let Some(is_active) = self.is_active {
            condition = condition.add(entity::budget::Column::IsActive.eq(is_active));
        }

        // Alert Enabled
        if let Some(alert_enabled) = self.alert_enabled {
            condition = condition.add(entity::budget::Column::AlertEnabled.eq(alert_enabled));
        }

        // Alert Threshold
        if let Some(alert_threshold) = &self.alert_threshold {
            condition = condition.add(entity::budget::Column::AlertThreshold.eq(alert_threshold));
        }

        condition
    }
}

// Converter struct
#[derive(Debug)]
pub struct BudgetConverter;

impl CrudConverter<entity::budget::Entity, BudgetCreate, BudgetUpdate> for BudgetConverter {
    fn create_to_active_model(
        &self,
        data: BudgetCreate,
    ) -> MijiResult<entity::budget::ActiveModel> {
        entity::budget::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::budget::Model,
        data: BudgetUpdate,
    ) -> MijiResult<entity::budget::ActiveModel> {
        entity::budget::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::budget::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "budget"
    }
}

impl BudgetConverter {
    pub async fn model_with_relations(
        &self,
        db: &DbConn,
        model: entity::budget::Model,
    ) -> MijiResult<BudgetWithAccount> {
        let account_service = get_account_service();
        let cny_service = get_currency_service();

        // 创建调整后的模型
        let adjusted_model = model.to_local();
        let (account, currency) = tokio::try_join!(
            async {
                match adjusted_model.account_serial_num.clone() {
                    Some(account_serial_num) => account_service
                        .get_account_with_relations(db, account_serial_num)
                        .await
                        .map(Some),
                    None => Ok(None),
                }
            },
            async {
                cny_service
                    .get_by_id(db, adjusted_model.currency.clone())
                    .await
            },
        )?;

        Ok(BudgetWithAccount {
            budget: adjusted_model,
            account,
            currency,
        })
    }
}
// 交易服务实现
pub struct BudgetService {
    inner: GenericCrudService<
        entity::budget::Entity,
        BudgetFilter,
        BudgetCreate,
        BudgetUpdate,
        BudgetConverter,
        BudgetHooks,
    >,
}

impl BudgetService {
    pub fn new(
        converter: BudgetConverter,
        hooks: BudgetHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for BudgetService {
    type Target = GenericCrudService<
        entity::budget::Entity,
        BudgetFilter,
        BudgetCreate,
        BudgetUpdate,
        BudgetConverter,
        BudgetHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

#[async_trait]
impl CrudService<entity::budget::Entity, BudgetFilter, BudgetCreate, BudgetUpdate>
    for BudgetService
{
    async fn create(&self, db: &DbConn, data: BudgetCreate) -> MijiResult<entity::budget::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(&self, db: &DbConn, id: String) -> MijiResult<entity::budget::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: BudgetUpdate,
    ) -> MijiResult<entity::budget::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::budget::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: BudgetFilter,
    ) -> MijiResult<Vec<entity::budget::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<BudgetFilter>,
    ) -> MijiResult<PagedResult<entity::budget::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<BudgetCreate>,
    ) -> MijiResult<Vec<entity::budget::Model>> {
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

    async fn count_with_filter(&self, db: &DbConn, filter: BudgetFilter) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

impl BudgetService {
    pub async fn get_budget_with_relations(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<BudgetWithAccount> {
        let model = self.get_by_id(db, serial_num).await?;
        self.converter().model_with_relations(db, model).await
    }
    pub async fn create_with_relations(
        &self,
        db: &DbConn,
        data: BudgetCreate,
    ) -> MijiResult<BudgetWithAccount> {
        let budget = self.create(db, data).await?;
        self.converter().model_with_relations(db, budget).await
    }

    pub async fn update_with_relations(
        &self,
        db: &DbConn,
        serial_num: String,
        data: BudgetUpdate,
    ) -> MijiResult<BudgetWithAccount> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_relations(db, model).await
    }

    pub async fn budget_list(
        &self,
        db: &DbConn,
        filters: BudgetFilter,
    ) -> MijiResult<Vec<BudgetWithAccount>> {
        let models = self.list_with_filter(db, filters).await?;
        let mut result = Vec::with_capacity(models.len());
        for m in models {
            result.push(self.converter().model_with_relations(db, m).await?);
        }
        Ok(result)
    }

    pub async fn budget_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<BudgetFilter>,
    ) -> MijiResult<PagedResult<BudgetWithAccount>> {
        let paged = self.list_paged(db, query).await?;
        let mut rows_with_relations = Vec::with_capacity(paged.rows.len());
        for m in paged.rows {
            let tx_with_rel = self.inner.converter().model_with_relations(db, m).await?;
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

pub fn get_budget_service() -> BudgetService {
    BudgetService::new(
        BudgetConverter,
        BudgetHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
