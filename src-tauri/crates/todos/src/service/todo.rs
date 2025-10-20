use std::sync::Arc;

use chrono::{Datelike, Timelike};
use common::{
    crud::service::{
        CrudConverter, CrudService, GenericCrudService, LocalizableConverter,
        update_entity_columns_simple,
    },
    error::{AppError, MijiResult},
    paginations::{DateRange, Filter, PagedQuery, PagedResult, Sortable},
    repeat_period_type::RepeatPeriodType,
    utils::date::DateUtils,
};
use entity::{localize::LocalizeModel, todo::Status};
use sea_orm::{
    ActiveModelTrait, ActiveValue, ColumnTrait, Condition, DbConn, EntityTrait, Order,
    PaginatorTrait, QueryFilter, QueryOrder, QuerySelect,
    prelude::{Expr, async_trait::async_trait},
};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    dto::todo::{TodoCreate, TodoUpdate},
    service::todo_hooks::TodoHooks,
};

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct TodosFilter {
    status: Option<String>,
    date_range: Option<DateRange>,
}

impl Filter<entity::todo::Entity> for TodosFilter {
    fn to_condition(&self) -> sea_orm::Condition {
        let mut condition = Condition::all();
        if let Some(status) = &self.status {
            condition = condition.add(entity::todo::Column::Status.eq(status));
        }
        if let Some(range) = &self.date_range {
            condition = condition.add(range.to_condition(entity::todo::Column::DueAt));
        }
        condition
    }
}

#[derive(Debug)]
pub struct TodosConverter;

impl CrudConverter<entity::todo::Entity, TodoCreate, TodoUpdate> for TodosConverter {
    fn create_to_active_model(&self, data: TodoCreate) -> MijiResult<entity::todo::ActiveModel> {
        entity::todo::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::todo::Model,
        data: TodoUpdate,
    ) -> MijiResult<entity::todo::ActiveModel> {
        entity::todo::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = ActiveValue::Set(model.serial_num.clone());
                active_model.created_at = ActiveValue::Set(model.created_at);
                active_model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::todo::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "todo"
    }
}

#[async_trait]
impl LocalizableConverter<entity::todo::Model> for TodosConverter {
    async fn model_with_local(
        &self,
        model: entity::todo::Model,
    ) -> MijiResult<entity::todo::Model> {
        Ok(model.to_local())
    }
}

// 待办事项服务实现
pub struct TodosService {
    inner: GenericCrudService<
        entity::todo::Entity,
        TodosFilter,
        TodoCreate,
        TodoUpdate,
        TodosConverter,
        TodoHooks,
    >,
}

impl TodosService {
    pub fn new(
        converter: TodosConverter,
        hooks: TodoHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for TodosService {
    type Target = GenericCrudService<
        entity::todo::Entity,
        TodosFilter,
        TodoCreate,
        TodoUpdate,
        TodosConverter,
        TodoHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TodosService {
    pub async fn todo_get(
        &self,
        db: &DbConn,
        serial_num: String,
    ) -> MijiResult<entity::todo::Model> {
        let opt_model = if serial_num.is_empty() {
            entity::todo::Entity::find().one(db).await?
        } else {
            Some(self.get_by_id(db, serial_num).await?)
        };
        let model = opt_model.ok_or_else(|| {
            AppError::simple(common::BusinessCode::NotFound, "todo notfound".to_string())
        })?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_create(
        &self,
        db: &DbConn,
        data: TodoCreate,
    ) -> MijiResult<entity::todo::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: TodoUpdate,
    ) -> MijiResult<entity::todo::Model> {
        let model = self.update(db, serial_num, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn todo_toggle(
        &self,
        db: &DbConn,
        serial_num: String,
        status: Status,
    ) -> MijiResult<entity::todo::Model> {
        let now = DateUtils::local_now();
        let mut updates = vec![
            (entity::todo::Column::Status, Expr::value(status.clone())),
            (entity::todo::Column::UpdatedAt, Expr::value(now)),
        ];

        if status == Status::Completed {
            updates.push((entity::todo::Column::CompletedAt, Expr::value(now)));
        }

        update_entity_columns_simple::<entity::todo::Entity, _>(
            db,
            vec![(entity::todo::Column::SerialNum, vec![serial_num.clone()])],
            updates,
        )
        .await?;
        self.get_by_id(db, serial_num).await
    }

    pub async fn todo_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn todo_list(&self, db: &DbConn) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.list(db).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_list_with_filter(
        &self,
        db: &DbConn,
        filter: TodosFilter,
    ) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.list_with_filter(db, filter).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<TodosFilter>,
    ) -> MijiResult<PagedResult<entity::todo::Model>> {
        // Step 1: Calculate total count of all todos (with original filter, ignoring status)
        let mut total_query_builder =
            entity::todo::Entity::find().filter(query.filter.to_condition());
        total_query_builder = query.sort_options.apply_sort(total_query_builder);
        let total_count = total_query_builder
            .clone()
            .count(db)
            .await
            .map_err(AppError::from)? as usize;

        // Step 2: Query all todos with appropriate sorting
        let mut query_builder = entity::todo::Entity::find().filter(query.filter.to_condition());

        // Apply sorting: use custom order if provided, otherwise use default
        if query.sort_options.custom_order_by.is_some() {
            // Use custom sorting from frontend
            query_builder = query.sort_options.apply_sort(query_builder);
        } else {
            // Use default sorting: status first, then priority
            query_builder = query_builder
                .order_by(
                    sea_orm::sea_query::Expr::cust(
                        "CASE WHEN status != 'Completed' THEN 0 ELSE 1 END",
                    ),
                    Order::Asc, // Non-completed first (0), completed last (1)
                )
                .order_by(entity::todo::Column::Priority, Order::Desc); // Then sort by Priority DESC
        }

        let offset = (query.current_page - 1) * query.page_size;
        let rows = query_builder
            .offset(offset as u64)
            .limit(query.page_size as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;

        // Calculate total pages
        let total_pages = total_count.div_ceil(query.page_size);

        PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        }
        .map_async(|rows| self.converter().localize_models(rows))
        .await
    }

    pub async fn todo_create_batch(
        &self,
        db: &DbConn,
        data: Vec<TodoCreate>,
    ) -> MijiResult<Vec<entity::todo::Model>> {
        let models = self.create_batch(db, data).await?;
        self.converter().localize_models(models).await
    }

    pub async fn todo_delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.delete_batch(db, ids).await
    }

    pub async fn todo_exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        self.exists(db, id).await
    }

    pub async fn todo_count(&self, db: &DbConn) -> MijiResult<u64> {
        self.count(db).await
    }

    pub async fn todo_count_with_filter(
        &self,
        db: &DbConn,
        filter: TodosFilter,
    ) -> MijiResult<u64> {
        self.count_with_filter(db, filter).await
    }

    /// 验证重复规则配置的有效性
    fn validate_repeat_config(
        repeat_type: &RepeatPeriodType,
        repeat_config: &serde_json::Value,
    ) -> bool {
        match repeat_type {
            RepeatPeriodType::Daily => {
                // Daily 需要 interval >= 1
                if let Some(interval) = repeat_config.get("interval").and_then(|v| v.as_i64()) {
                    interval >= 1
                } else {
                    true // 没有 interval 时使用默认值 1
                }
            }
            RepeatPeriodType::Weekly => {
                // Weekly 需要 interval >= 1，daysOfWeek 数组不为空且有效
                let interval_valid = if let Some(interval) =
                    repeat_config.get("interval").and_then(|v| v.as_i64())
                {
                    interval >= 1
                } else {
                    true
                };

                let days_valid = if let Some(days_array) =
                    repeat_config.get("daysOfWeek").and_then(|v| v.as_array())
                {
                    !days_array.is_empty()
                        && days_array.iter().any(|v| {
                            v.as_str()
                                .map(|s| {
                                    matches!(
                                        s.to_lowercase().as_str(),
                                        "mon"
                                            | "monday"
                                            | "tue"
                                            | "tuesday"
                                            | "wed"
                                            | "wednesday"
                                            | "thu"
                                            | "thursday"
                                            | "fri"
                                            | "friday"
                                            | "sat"
                                            | "saturday"
                                            | "sun"
                                            | "sunday"
                                    )
                                })
                                .unwrap_or(false)
                        })
                } else {
                    true // 没有 daysOfWeek 时使用当前星期几
                };

                interval_valid && days_valid
            }
            RepeatPeriodType::Monthly => {
                // Monthly 需要 interval >= 1，day 配置有效
                let interval_valid = if let Some(interval) =
                    repeat_config.get("interval").and_then(|v| v.as_i64())
                {
                    interval >= 1
                } else {
                    true
                };

                let day_valid = if let Some(day_obj) = repeat_config.get("day") {
                    if let Some(day_type) = day_obj.get("type").and_then(|v| v.as_str()) {
                        match day_type.to_lowercase().as_str() {
                            "last" => true,
                            "day" => day_obj
                                .get("value")
                                .and_then(|v| v.as_u64())
                                .map(|v| (1..=31).contains(&v))
                                .unwrap_or(false),
                            _ => false,
                        }
                    } else if day_obj.is_number() {
                        day_obj
                            .as_u64()
                            .map(|v| (1..=31).contains(&v))
                            .unwrap_or(false)
                    } else {
                        false
                    }
                } else {
                    true // 没有 day 时使用当前日
                };

                interval_valid && day_valid
            }
            RepeatPeriodType::Yearly => {
                // Yearly 需要 interval >= 1，month/day 有效
                let interval_valid = if let Some(interval) =
                    repeat_config.get("interval").and_then(|v| v.as_i64())
                {
                    interval >= 1
                } else {
                    true
                };

                let month_valid =
                    if let Some(month) = repeat_config.get("month").and_then(|v| v.as_u64()) {
                        (1..=12).contains(&month)
                    } else {
                        true
                    };

                let day_valid = if let Some(day) = repeat_config.get("day").and_then(|v| v.as_u64())
                {
                    (1..=31).contains(&day)
                } else {
                    true
                };

                interval_valid && month_valid && day_valid
            }
            RepeatPeriodType::Custom => {
                // Custom 需要 description 不为空
                repeat_config
                    .get("description")
                    .and_then(|v| v.as_str())
                    .map(|s| !s.trim().is_empty())
                    .unwrap_or(false)
            }
            RepeatPeriodType::None => false, // None 类型不应该有重复规则
        }
    }

    pub async fn auto_process_create_todo(db: &DbConn) -> MijiResult<()> {
        let todos = entity::todo::Entity::find()
            .filter(entity::todo::Column::Status.ne(Status::Completed))
            .all(db)
            .await
            .map_err(AppError::from)?;
        for td in todos {
            // 解析重复类型
            let repeat_type = match RepeatPeriodType::from_string(&td.repeat_period_type) {
                Some(rt) => rt,
                None => {
                    tracing::warn!("Unknown repeat period type: {}", td.repeat_period_type);
                    continue;
                }
            };

            if repeat_type.is_none() {
                continue;
            }

            // 验证重复规则配置
            if !Self::validate_repeat_config(&repeat_type, &td.repeat) {
                tracing::warn!(
                    "Invalid repeat config for todo {}: type={:?}, config={:?}",
                    td.serial_num,
                    repeat_type,
                    td.repeat
                );
                continue;
            }

            // 基准时间：根据需求说明，使用当前待办的创建时间
            let base = td.created_at;

            // 解析 repeat JSON 中的细节（如 interval、daysOfWeek、day 等）
            let repeat_json = &td.repeat;
            let get_number = |key: &str, default_val: i64| -> i64 {
                repeat_json
                    .get(key)
                    .and_then(|v| v.as_i64())
                    .unwrap_or(default_val)
            };

            // 计算下一次 due 时间
            let next_due = match repeat_type {
                RepeatPeriodType::Daily => {
                    let interval = get_number("interval", 1).max(1);
                    base + chrono::Duration::days(interval)
                }
                RepeatPeriodType::Weekly => {
                    let interval = get_number("interval", 1).max(1);

                    // 解析 daysOfWeek 数组
                    let days_of_week = if let Some(days_array) =
                        repeat_json.get("daysOfWeek").and_then(|v| v.as_array())
                    {
                        days_array
                            .iter()
                            .filter_map(|v| v.as_str())
                            .filter_map(|s| match s.to_lowercase().as_str() {
                                "mon" | "monday" => Some(chrono::Weekday::Mon),
                                "tue" | "tuesday" => Some(chrono::Weekday::Tue),
                                "wed" | "wednesday" => Some(chrono::Weekday::Wed),
                                "thu" | "thursday" => Some(chrono::Weekday::Thu),
                                "fri" | "friday" => Some(chrono::Weekday::Fri),
                                "sat" | "saturday" => Some(chrono::Weekday::Sat),
                                "sun" | "sunday" => Some(chrono::Weekday::Sun),
                                _ => None,
                            })
                            .collect::<Vec<_>>()
                    } else {
                        vec![base.weekday()]
                    };

                    if days_of_week.is_empty() {
                        // 如果没有有效的星期几，使用当前星期几
                        base + chrono::Duration::weeks(interval)
                    } else {
                        // 找到下一个符合的星期几
                        let mut next_date = base;
                        let mut weeks_added = 0;

                        loop {
                            if days_of_week.contains(&next_date.weekday()) {
                                break;
                            }
                            next_date += chrono::Duration::days(1);

                            // 如果跨周了，增加周数计数
                            if next_date.weekday() == chrono::Weekday::Mon && weeks_added == 0 {
                                weeks_added = 1;
                            }
                        }

                        // 如果当前日期就在目标星期几中，需要跳到下一个周期
                        if next_date == base && weeks_added == 0 {
                            next_date += chrono::Duration::weeks(interval);
                            // 重新找到下一个符合的星期几
                            loop {
                                if days_of_week.contains(&next_date.weekday()) {
                                    break;
                                }
                                next_date += chrono::Duration::days(1);
                            }
                        } else if weeks_added > 0 {
                            // 如果已经跨周了，需要加上剩余的周数
                            next_date += chrono::Duration::weeks(interval - 1);
                        }

                        next_date
                    }
                }
                RepeatPeriodType::Monthly => {
                    let interval = get_number("interval", 1).max(1) as u32;

                    // 计算目标月份
                    let mut year = base.year();
                    let mut month = base.month();

                    // 推进月份，处理跨年情况
                    for _ in 0..interval {
                        if month == 12 {
                            month = 1;
                            year += 1;
                        } else {
                            month += 1;
                        }
                    }

                    // 计算目标日，支持多种格式
                    let target_day = if let Some(day_obj) = repeat_json.get("day") {
                        // 支持 { "type": "Day", "value": n } 或 { "type": "Last" }
                        if let Some(day_type) = day_obj.get("type").and_then(|v| v.as_str()) {
                            if day_type.eq_ignore_ascii_case("Last") {
                                common::utils::date::DateUtils::days_in_month(year, month)
                            } else if day_type.eq_ignore_ascii_case("Day") {
                                day_obj
                                    .get("value")
                                    .and_then(|v| v.as_u64())
                                    .map(|v| v as u32)
                                    .filter(|v| *v >= 1)
                                    .unwrap_or(base.day())
                                    .min(common::utils::date::DateUtils::days_in_month(year, month))
                            } else {
                                // 未知类型，使用当前日
                                base.day()
                                    .min(common::utils::date::DateUtils::days_in_month(year, month))
                            }
                        } else if let Some(day_value) = day_obj.as_u64() {
                            // 直接是数字格式
                            (day_value as u32)
                                .max(1)
                                .min(common::utils::date::DateUtils::days_in_month(year, month))
                        } else {
                            base.day()
                                .min(common::utils::date::DateUtils::days_in_month(year, month))
                        }
                    } else {
                        // 没有指定 day，使用当前日
                        base.day()
                            .min(common::utils::date::DateUtils::days_in_month(year, month))
                    };

                    // 构建目标日期时间
                    chrono::NaiveDate::from_ymd_opt(year, month, target_day)
                        .and_then(|date| {
                            date.and_hms_opt(base.hour(), base.minute(), base.second())
                        })
                        .map(|naive| naive.and_utc().fixed_offset())
                        .unwrap_or_else(|| {
                            // 如果日期无效（如2月30日），回退到下个月第一天
                            let mut fallback_year = year;
                            let mut fallback_month = month;
                            if fallback_month == 12 {
                                fallback_month = 1;
                                fallback_year += 1;
                            } else {
                                fallback_month += 1;
                            }
                            chrono::NaiveDate::from_ymd_opt(fallback_year, fallback_month, 1)
                                .unwrap()
                                .and_hms_opt(base.hour(), base.minute(), base.second())
                                .unwrap()
                                .and_utc()
                                .fixed_offset()
                        })
                }
                RepeatPeriodType::Yearly => {
                    let interval = get_number("interval", 1).max(1);
                    let year = base.year() + interval as i32;
                    let mut month = base.month();
                    let mut day = base.day();

                    // 支持 repeat 中的 month/day 覆盖
                    if let Some(m) = repeat_json.get("month").and_then(|v| v.as_u64()) {
                        month = (m as u32).clamp(1, 12);
                    }
                    if let Some(d) = repeat_json.get("day").and_then(|v| v.as_u64()) {
                        let maxd = common::utils::date::DateUtils::days_in_month(year, month);
                        day = (d as u32).clamp(1, maxd);
                    } else {
                        let maxd = common::utils::date::DateUtils::days_in_month(year, month);
                        day = day.min(maxd);
                    }

                    // 构建目标日期时间，处理无效日期
                    chrono::NaiveDate::from_ymd_opt(year, month, day)
                        .and_then(|date| {
                            date.and_hms_opt(base.hour(), base.minute(), base.second())
                        })
                        .map(|naive| naive.and_utc().fixed_offset())
                        .unwrap_or_else(|| {
                            // 如果日期无效（如闰年2月29日），回退到3月1日
                            chrono::NaiveDate::from_ymd_opt(year, 3, 1)
                                .unwrap()
                                .and_hms_opt(base.hour(), base.minute(), base.second())
                                .unwrap()
                                .and_utc()
                                .fixed_offset()
                        })
                }
                RepeatPeriodType::Custom => {
                    // Custom 类型：根据 description 进行简单处理
                    // 这里可以根据具体业务需求扩展
                    let description = repeat_json
                        .get("description")
                        .and_then(|v| v.as_str())
                        .unwrap_or("");

                    // 简单的自定义逻辑：如果是"工作日"相关描述，按工作日计算
                    if description.to_lowercase().contains("workday")
                        || description.to_lowercase().contains("工作日")
                    {
                        let interval = get_number("interval", 1).max(1);
                        let mut next_date = base;
                        let mut workdays_added = 0;

                        while workdays_added < interval {
                            next_date += chrono::Duration::days(1);
                            let weekday = next_date.weekday();
                            if weekday != chrono::Weekday::Sat && weekday != chrono::Weekday::Sun {
                                workdays_added += 1;
                            }
                        }
                        next_date
                    } else {
                        // 其他自定义类型暂不处理，跳过
                        continue;
                    }
                }
                RepeatPeriodType::None => {
                    // None 类型不应该到达这里，但为了完整性
                    continue;
                }
            };

            // 避免重复创建：若已存在相同 parent_id + due_at 的记录，则跳过
            let exists = entity::todo::Entity::find()
                .filter(
                    Condition::all()
                        .add(entity::todo::Column::ParentId.eq(td.serial_num.clone()))
                        .add(entity::todo::Column::DueAt.eq(next_due)),
                )
                .count(db)
                .await
                .map_err(AppError::from)?
                > 0;
            if exists {
                tracing::debug!(
                    "Skipping duplicate todo for parent {} at {}",
                    td.serial_num,
                    next_due
                );
                continue;
            }

            // 生成下一条待办
            let create = TodoCreate {
                core: crate::dto::todo::TodoBase {
                    title: td.title.clone(),
                    description: td.description.clone(),
                    due_at: next_due,
                    priority: td.priority.clone(),
                    status: Status::NotStarted,
                    repeat_period_type: td.repeat_period_type.clone(),
                    repeat: td.repeat.clone(),
                    completed_at: None,
                    assignee_id: td.assignee_id.clone(),
                    progress: 0,
                    location: td.location.clone(),
                    owner_id: td.owner_id.clone(),
                    is_archived: false,
                    is_pinned: false,
                    estimate_minutes: td.estimate_minutes,
                    reminder_count: 0,
                    parent_id: Some(td.serial_num.clone()),
                    subtask_order: None,
                    // 提醒相关字段继承
                    reminder_enabled: td.reminder_enabled,
                    reminder_advance_value: td.reminder_advance_value,
                    reminder_advance_unit: td.reminder_advance_unit.clone(),
                    last_reminder_sent_at: None,
                    reminder_frequency: td.reminder_frequency.clone(),
                    snooze_until: None,
                    reminder_methods: td.reminder_methods.clone(),
                    timezone: td.timezone.clone(),
                    smart_reminder_enabled: td.smart_reminder_enabled,
                    location_based_reminder: td.location_based_reminder,
                    weather_dependent: td.weather_dependent,
                    priority_boost_enabled: td.priority_boost_enabled,
                    batch_reminder_id: None,
                },
            };

            match entity::todo::ActiveModel::try_from(create) {
                Ok(active) => match active.insert(db).await {
                    Ok(new_todo) => {
                        tracing::info!(
                            "Created repeated todo {} for parent {} due_at={}",
                            new_todo.serial_num,
                            td.serial_num,
                            next_due
                        );
                    }
                    Err(e) => {
                        tracing::error!(
                            "Failed to insert repeated todo for parent {}: {}",
                            td.serial_num,
                            e
                        );
                    }
                },
                Err(e) => {
                    tracing::error!(
                        "Failed to create repeated todo for parent {}: {}",
                        td.serial_num,
                        e
                    );
                }
            }
        }
        Ok(())
    }
}

pub fn get_todos_service() -> TodosService {
    TodosService::new(
        TodosConverter,
        TodoHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
