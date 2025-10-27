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

/// 提醒类型配置
struct ReminderTypeConfig {
    should_use_escalation: bool,
    should_use_smart_reminder: bool,
    should_use_auto_reschedule: bool,
    should_use_payment_reminder: bool,
    is_finance: bool,
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
            // 获取类型配置
            let config = Self::get_type_config(br);

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

            // 是否已支付的检查
            if br.is_paid {
                // 已支付：只处理支付提醒（如果启用）
                if !br.payment_reminder_enabled {
                    return false;
                }
                // 支付提醒：需要已支付且有最后一次提醒记录，用于确认支付
                if br.last_reminder_sent_at.is_none() {
                    return false;
                }
            } else {
                // 未支付：检查是否已过期并需要升级提醒
                if now > br.due_at {
                    // 账单已过期
                    let should_escalate = br.escalation_enabled || config.should_use_escalation;

                    if should_escalate {
                        // 启用升级提醒：检查是否超过了升级时间
                        if let Some(escalation_hours) = br.escalation_after_hours
                            && let Some(last_reminder) = br.last_reminder_sent_at
                        {
                            let escalation_time =
                                last_reminder + chrono::Duration::hours(escalation_hours as i64);
                            if now < escalation_time {
                                return false;
                            }
                        }
                        // 未设置升级时间且已过期，立即提醒
                    } else if br.payment_reminder_enabled || config.should_use_payment_reminder {
                        // 启用支付提醒：账单已过期，检查是否需要提醒
                        // 需要最后一次提醒时间
                        if br.last_reminder_sent_at.is_none() {
                            return false;
                        }
                        // 检查提醒频率
                        if let Some(last) = br.last_reminder_sent_at
                            && let Some(freq) =
                                Self::parse_frequency_to_duration(&br.reminder_frequency)
                            && last + freq > now
                        {
                            return false;
                        }
                    } else {
                        // 未启用支付提醒，不再提醒已过期的账单
                        // 但财务类型即使过期也要提醒
                        if !config.is_finance {
                            return false;
                        }
                    }
                } else {
                    // 账单未过期，检查正常的提醒触发时间
                    let advance =
                        Self::calc_advance_duration(br.advance_value, br.advance_unit.clone());
                    let trigger_at = br.remind_date.max(br.due_at - advance);
                    if now < trigger_at {
                        return false;
                    }

                    // 智能提醒：根据支付历史调整频率（仅当启用时）
                    let should_use_smart =
                        br.smart_reminder_enabled || config.should_use_smart_reminder;
                    let freq = if should_use_smart {
                        Self::adjust_smart_frequency(&br.reminder_frequency, now, br.due_at)
                    } else {
                        Self::parse_frequency_to_duration(&br.reminder_frequency)
                    };

                    // 频率窗口：last + freq <= now（once 已上面处理）
                    if let Some(last) = br.last_reminder_sent_at
                        && let Some(freq) = freq
                        && last + freq > now
                    {
                        return false;
                    }
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

    /// 智能提醒：根据到期时间调整提醒频率
    /// 距离到期时间越近，提醒频率越高
    fn adjust_smart_frequency(
        _freq: &Option<String>,
        now: chrono::DateTime<chrono::FixedOffset>,
        due_at: chrono::DateTime<chrono::FixedOffset>,
    ) -> Option<chrono::Duration> {
        let time_until_due = due_at.signed_duration_since(now);
        let hours_until_due = time_until_due.num_hours();

        // 基于距离到期时间调整频率
        match hours_until_due {
            h if h < 0 => Some(chrono::Duration::hours(1)), // 已过期：每小时提醒
            h if h < 24 => Some(chrono::Duration::hours(6)), // 24小时内：每6小时
            h if h < 72 => Some(chrono::Duration::hours(12)), // 3天内：每12小时
            _ => Some(chrono::Duration::days(1)),           // 更远：每天
        }
    }

    /// 根据提醒类型获取应启用的功能配置
    fn get_type_config(br: &entity::bil_reminder::Model) -> ReminderTypeConfig {
        match br.r#type.as_str() {
            // 财务类型：启用所有高级功能
            "Bill" | "Tax" | "Insurance" | "Loan" => ReminderTypeConfig {
                should_use_escalation: true,
                should_use_smart_reminder: true,
                should_use_auto_reschedule: true,
                should_use_payment_reminder: true,
                is_finance: true,
            },
            // 健康类型：用药等紧急类型启用升级
            "Medicine" | "Health" => ReminderTypeConfig {
                should_use_escalation: true,
                should_use_smart_reminder: true,
                should_use_auto_reschedule: false,
                should_use_payment_reminder: false,
                is_finance: false,
            },
            // 工作类型：截止日期启用升级
            "Deadline" | "Work" => ReminderTypeConfig {
                should_use_escalation: true,
                should_use_smart_reminder: true,
                should_use_auto_reschedule: false,
                should_use_payment_reminder: false,
                is_finance: false,
            },
            // 日常类型：禁用所有高级功能
            "Exercise" | "Diet" | "Routine" | "Sleep" => ReminderTypeConfig {
                should_use_escalation: false,
                should_use_smart_reminder: false,
                should_use_auto_reschedule: false,
                should_use_payment_reminder: false,
                is_finance: false,
            },
            // 紧急类型：启用所有高级功能
            "Urgent" | "Important" => ReminderTypeConfig {
                should_use_escalation: true,
                should_use_smart_reminder: true,
                should_use_auto_reschedule: false,
                should_use_payment_reminder: false,
                is_finance: false,
            },
            // 默认配置：使用用户设置
            _ => ReminderTypeConfig {
                should_use_escalation: br.escalation_enabled,
                should_use_smart_reminder: br.smart_reminder_enabled,
                should_use_auto_reschedule: br.auto_reschedule,
                should_use_payment_reminder: br.payment_reminder_enabled,
                is_finance: false,
            },
        }
    }

    // ======= 发送系统通知 =======
    pub async fn send_bil_system_notification(
        &self,
        app: &tauri::AppHandle,
        br: &entity::bil_reminder::Model,
    ) -> MijiResult<()> {
        #[allow(unused_imports)]
        use tauri_plugin_notification::NotificationExt;

        let now = DateUtils::local_now();
        let is_overdue = now > br.due_at;
        let is_escalation = br.escalation_enabled && is_overdue;

        // 构建标题和内容
        let (title, body) = if is_escalation {
            // 升级提醒
            let urgency = if br.priority == "high" {
                "紧急"
            } else if br.priority == "medium" {
                "重要"
            } else {
                ""
            };
            (
                format!("⚠️ {}账单升级提醒: {}", urgency, br.name),
                self.build_escalation_body(br),
            )
        } else if is_overdue && !br.is_paid {
            // 已过期未支付
            (
                format!("💰 账单逾期: {}", br.name),
                self.build_overdue_body(br),
            )
        } else if br.is_paid && br.payment_reminder_enabled {
            // 支付确认提醒
            (
                format!("✅ 支付确认: {}", br.name),
                "请确认账单已支付完成。".to_string(),
            )
        } else {
            // 正常提醒
            (
                format!("账单提醒: {}", br.name),
                br.description
                    .clone()
                    .unwrap_or_else(|| "您有一条账单提醒".to_string()),
            )
        };

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
                "isOverdue": is_overdue,
                "isEscalation": is_escalation,
                "isPaid": br.is_paid,
            }),
        );
        Ok(())
    }

    /// 构建升级提醒内容
    fn build_escalation_body(&self, br: &entity::bil_reminder::Model) -> String {
        let mut parts = Vec::new();

        if let Some(amount) = &br.amount
            && let Some(currency) = &br.currency
        {
            parts.push(format!("金额: {}{}", currency, amount));
        }

        let overdue_days = (DateUtils::local_now() - br.due_at).num_days();
        if overdue_days > 0 {
            parts.push(format!("逾期 {} 天", overdue_days));
        }

        parts.push(format!(
            "优先级: {}",
            match br.priority.as_str() {
                "high" => "高",
                "medium" => "中",
                _ => "低",
            }
        ));

        parts.join(" | ")
    }

    /// 构建逾期提醒内容
    fn build_overdue_body(&self, br: &entity::bil_reminder::Model) -> String {
        let mut parts = Vec::new();

        if let Some(amount) = &br.amount
            && let Some(currency) = &br.currency
        {
            parts.push(format!("金额: {}{}", currency, amount));
        }

        let overdue_days = (DateUtils::local_now() - br.due_at).num_days();
        if overdue_days > 0 {
            parts.push(format!("已逾期 {} 天", overdue_days));
        }

        if parts.is_empty() {
            "此账单已逾期，请尽快处理。".to_string()
        } else {
            parts.join(" | ")
        }
    }

    // ======= 标记已提醒 =======
    pub async fn mark_bil_reminded(
        &self,
        db: &DbConn,
        br: &entity::bil_reminder::Model,
        when: chrono::DateTime<chrono::FixedOffset>,
        batch_id: Option<String>,
    ) -> MijiResult<()> {
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
        if br.reminder_frequency.as_deref() == Some("once") {
            updates.push((entity::bil_reminder::Column::Enabled, Expr::value(false)));
        }

        // 自动重新安排：如果启用且当前已过期，根据重复周期重新安排
        let config = Self::get_type_config(br);
        let should_reschedule = br.auto_reschedule || config.should_use_auto_reschedule;

        if should_reschedule
            && when > br.due_at
            && let Some(next_due) = self.calculate_next_due_date(br).await?
        {
            updates.push((entity::bil_reminder::Column::DueAt, Expr::value(next_due)));
            updates.push((
                entity::bil_reminder::Column::RemindDate,
                Expr::value(
                    next_due
                        - Self::calc_advance_duration(br.advance_value, br.advance_unit.clone()),
                ),
            ));
            // 重置提醒状态
            updates.push((
                entity::bil_reminder::Column::LastReminderSentAt,
                Expr::value(None::<chrono::DateTime<chrono::FixedOffset>>),
            ));
            updates.push((entity::bil_reminder::Column::IsPaid, Expr::value(false)));
            updates.push((
                entity::bil_reminder::Column::SnoozeUntil,
                Expr::value(None::<chrono::DateTime<chrono::FixedOffset>>),
            ));
            tracing::info!("Auto-rescheduled bill {} to {}", br.serial_num, next_due);
        }

        update_entity_columns_simple::<entity::bil_reminder::Entity, _>(
            db,
            vec![(
                entity::bil_reminder::Column::SerialNum,
                vec![br.serial_num.clone()],
            )],
            updates,
        )
        .await?;

        Ok(())
    }

    /// 计算下一个到期日期（根据重复周期）
    async fn calculate_next_due_date(
        &self,
        br: &entity::bil_reminder::Model,
    ) -> MijiResult<Option<chrono::DateTime<chrono::FixedOffset>>> {
        // 简单的重复周期处理
        let current_due = br.due_at;

        match br.repeat_period_type.as_str() {
            "none" => Ok(None),
            "daily" => Ok(Some(current_due + chrono::Duration::days(1))),
            "weekly" => Ok(Some(current_due + chrono::Duration::weeks(1))),
            "biweekly" => Ok(Some(current_due + chrono::Duration::weeks(2))),
            "monthly" => {
                // 月份加法：使用 months(1) 或 days(30)
                Ok(Some(current_due + chrono::Duration::days(30)))
            }
            "quarterly" => Ok(Some(current_due + chrono::Duration::days(90))),
            "yearly" => Ok(Some(current_due + chrono::Duration::days(365))),
            _ => {
                // 尝试从 repeat_period JSON 中解析
                if let Some(period) = br.repeat_period.get("value")
                    && let Some(days) = period.get("days").and_then(|v| v.as_u64())
                {
                    return Ok(Some(current_due + chrono::Duration::days(days as i64)));
                }
                Ok(None)
            }
        }
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
        let mut auto_rescheduled = 0usize;

        for br in rows {
            match self.send_bil_system_notification(app, &br).await {
                Ok(_) => {
                    // 检查是否需要自动重新安排
                    let needs_reschedule = br.auto_reschedule && now > br.due_at;

                    self.mark_bil_reminded(db, &br, now, batch_id.clone())
                        .await?;
                    sent += 1;

                    if needs_reschedule {
                        auto_rescheduled += 1;
                    }
                }
                Err(e) => tracing::error!("发送账单提醒失败: {}", e),
            }
        }

        tracing::info!("发送 {} 条账单提醒", sent);
        if auto_rescheduled > 0 {
            tracing::info!("自动重新安排了 {} 个过期账单", auto_rescheduled);
        }

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
