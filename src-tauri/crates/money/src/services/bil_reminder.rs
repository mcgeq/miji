use chrono::{DateTime, FixedOffset};
use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, update_entity_columns_simple},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use macros::add_filter_condition;
use sea_orm::{
    ActiveValue, ColumnTrait, Condition, DbConn, EntityTrait, QueryFilter, prelude::Expr,
    prelude::async_trait::async_trait,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::Emitter;
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
    pub repeat_period_type: Option<String>,
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

// 账单提醒服务实现
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

    // ======= 通知辅助：频率与提前量 =======
    fn parse_frequency_to_duration(freq: &Option<String>) -> Option<chrono::Duration> {
        let s = freq.as_ref()?.trim();
        if s.is_empty() {
            return None;
        }
        let (num_str, unit) = s.split_at(s.len().saturating_sub(1));
        let Ok(n) = num_str.trim().parse::<i64>() else {
            return None;
        };
        match unit {
            "m" | "M" => Some(chrono::Duration::minutes(n)),
            "h" | "H" => Some(chrono::Duration::hours(n)),
            "d" | "D" => Some(chrono::Duration::days(n)),
            _ => None,
        }
    }

    fn calc_advance_duration(value: Option<i32>, unit: Option<String>) -> chrono::Duration {
        let v = value.unwrap_or(0) as i64;
        match unit.as_deref() {
            Some("minute") | Some("minutes") | Some("m") => chrono::Duration::minutes(v),
            Some("hour") | Some("hours") | Some("h") => chrono::Duration::hours(v),
            Some("day") | Some("days") | Some("d") => chrono::Duration::days(v),
            _ => chrono::Duration::zero(),
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

impl BilReminderConverter {
    pub fn model_with_relations(
        &self,
        model: entity::bil_reminder::Model,
    ) -> MijiResult<entity::bil_reminder::Model> {
        Ok(model.to_local())
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
            repeat_period_type,
            entity::bil_reminder::Column::RepeatPeriodType,
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
        let model = self.inner.create(db, data).await?;
        self.converter().model_with_relations(model)
    }

    async fn get_by_id(&self, db: &DbConn, id: String) -> MijiResult<entity::bil_reminder::Model> {
        let model = self.inner.get_by_id(db, id).await?;
        self.converter().model_with_relations(model)
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: BilReminderUpdate,
    ) -> MijiResult<entity::bil_reminder::Model> {
        let model = self.inner.update(db, id, data).await?;
        self.converter().model_with_relations(model)
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::bil_reminder::Model>> {
        let models = self.inner.list(db).await?;
        models
            .into_iter()
            .map(|m| self.converter().model_with_relations(m))
            .collect()
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: BilReminderFilters,
    ) -> MijiResult<Vec<entity::bil_reminder::Model>> {
        let models = self.inner.list_with_filter(db, filter).await?;
        models
            .into_iter()
            .map(|m| self.converter().model_with_relations(m))
            .collect()
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<BilReminderFilters>,
    ) -> MijiResult<PagedResult<entity::bil_reminder::Model>> {
        let paged = self.inner.list_paged(db, query).await?;
        let rows_with_relations = paged
            .rows
            .into_iter()
            .map(|m| self.converter().model_with_relations(m))
            .collect::<MijiResult<Vec<_>>>()?;

        Ok(PagedResult {
            rows: rows_with_relations,
            total_count: paged.total_count,
            current_page: paged.current_page,
            page_size: paged.page_size,
            total_pages: paged.total_pages,
        })
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

impl BilReminderService {
    // ======= 查询需要提醒的账单 =======
    pub async fn find_due_bil_reminders(
        &self,
        db: &DbConn,
        now: chrono::DateTime<chrono::FixedOffset>,
    ) -> MijiResult<Vec<entity::bil_reminder::Model>> {
        let mut rows = entity::bil_reminder::Entity::find()
            .filter(
                Condition::all()
                    .add(entity::bil_reminder::Column::Enabled.eq(true))
                    .add(entity::bil_reminder::Column::IsDeleted.eq(false)),
            )
            .all(db)
            .await
            .map_err(AppError::from)?;

        let before = rows.len();
        rows.retain(|br| {
            // 仅一次：若已经提醒过一次（存在 last_reminder_sent_at），则不再提醒
            if matches!(br.reminder_frequency.as_deref(), Some("once"))
                && br.last_reminder_sent_at.is_some()
            {
                return false;
            }

            // 打盹
            if let Some(snooze) = br.snooze_until
                && now < snooze
            {
                return false;
            }

            // 触发时间：优先使用 remind_date，否则使用 due_at - advance
            let advance = Self::calc_advance_duration(br.advance_value, br.advance_unit.clone());
            let trigger_at = br.remind_date.max(br.due_at - advance);
            if now < trigger_at {
                return false;
            }

            // 频率窗口：last + freq <= now（once 已上面处理）
            if let Some(last) = br.last_reminder_sent_at {
                if let Some(freq) = Self::parse_frequency_to_duration(&br.reminder_frequency)
                    && last + freq > now
                {
                    return false;
                }
            }

            // 系统通知选择：desktop 或 mobile 任一为 true 即允许，否则拦截
            let methods_ok = match &br.reminder_methods {
                Some(v) => {
                    let desktop = v.get("desktop").and_then(|b| b.as_bool()).unwrap_or(false);
                    let mobile = v.get("mobile").and_then(|b| b.as_bool()).unwrap_or(false);
                    desktop || mobile
                }
                None => true,
            };
            if !methods_ok {
                return false;
            }

            true
        });
        tracing::debug!("bil reminders filtered: {} -> {}", before, rows.len());
        Ok(rows)
    }

    // ======= 发送系统通知 =======
    pub async fn send_bil_system_notification(
        &self,
        app: &tauri::AppHandle,
        br: &entity::bil_reminder::Model,
    ) -> MijiResult<()> {
        #[allow(unused_imports)]
        use tauri_plugin_notification::NotificationExt;

        let title = format!("账单提醒: {}", br.name);
        let body = br
            .description
            .clone()
            .unwrap_or_else(|| "您有一条账单提醒".to_string());

        app.notification()
            .builder()
            .title(title)
            .body(body)
            .show()
            .map_err(|e| AppError::simple(common::BusinessCode::SystemError, e.to_string()))?;

        let _ = app.emit(
            "bil-reminder-fired",
            serde_json::json!({
                "serialNum": br.serial_num,
                "dueAt": br.due_at.timestamp(),
            }),
        );
        Ok(())
    }

    // ======= 标记已提醒 =======
    pub async fn mark_bil_reminded(
        &self,
        db: &DbConn,
        serial_num: &str,
        when: chrono::DateTime<chrono::FixedOffset>,
        batch_id: Option<String>,
    ) -> MijiResult<()> {
        if let Some(model) = entity::bil_reminder::Entity::find_by_id(serial_num.to_string())
            .one(db)
            .await
            .map_err(AppError::from)?
        {
            let mut updates: Vec<(entity::bil_reminder::Column, sea_orm::sea_query::SimpleExpr)> = vec![
                (
                    entity::bil_reminder::Column::LastReminderSentAt,
                    Expr::value(when),
                ),
                (
                    entity::bil_reminder::Column::BatchReminderId,
                    Expr::value(batch_id.clone()),
                ),
                (entity::bil_reminder::Column::UpdatedAt, Expr::value(when)),
            ];
            // 若频率为 once，发送后自动关闭 enabled
            if model.reminder_frequency.as_deref() == Some("once") {
                updates.push((entity::bil_reminder::Column::Enabled, Expr::value(false)));
            }

            update_entity_columns_simple::<entity::bil_reminder::Entity, _>(
                db,
                vec![(
                    entity::bil_reminder::Column::SerialNum,
                    vec![serial_num.to_string()],
                )],
                updates,
            )
            .await?;
        }
        Ok(())
    }

    // ======= 处理入口 =======
    pub async fn process_due_bil_reminders(
        &self,
        app: &tauri::AppHandle,
        db: &DbConn,
    ) -> MijiResult<usize> {
        let now = DateUtils::local_now();
        let rows = self.find_due_bil_reminders(db, now).await?;
        if rows.is_empty() {
            return Ok(0);
        }
        let batch_id = Some(common::utils::uuid::McgUuid::uuid(38));
        let mut sent = 0usize;
        for br in rows {
            match self.send_bil_system_notification(app, &br).await {
                Ok(_) => {
                    self.mark_bil_reminded(db, &br.serial_num, now, batch_id.clone())
                        .await?;
                    sent += 1;
                }
                Err(e) => tracing::error!("发送账单提醒失败: {}", e),
            }
        }
        tracing::info!("发送 {} 条账单提醒", sent);
        Ok(sent)
    }
}

pub fn get_bil_reminder_service() -> BilReminderService {
    BilReminderService::new(
        BilReminderConverter,
        BilReminderHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
