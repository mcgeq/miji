use std::collections::HashMap;

use chrono::{Datelike, NaiveDate};
use common::{
    crud::service::{CrudConverter, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    log::logger::NoopLogger,
    paginations::{EmptyFilter, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::prelude::Decimal;
use sea_orm::{
    ActiveValue, ColumnTrait, Condition, DbConn, EntityTrait, Order, PaginatorTrait, QueryFilter,
    QueryOrder, QuerySelect, prelude::async_trait::async_trait,
};

use crate::{
    dto::settlement_records::{
        AutoSettlementConfig, CancelSettlement, CompleteSettlement, SettlementRecordCreate,
        SettlementRecordQuery, SettlementRecordResponse, SettlementRecordUpdate, SettlementStats,
        SettlementSuggestion,
    },
    services::{
        debt_relations::DebtRelationsService, settlement_optimizer::SettlementOptimizer,
        settlement_records_hooks::SettlementRecordsHooks,
    },
};

pub type SettlementRecordsFilter = EmptyFilter;

#[derive(Debug)]
pub struct SettlementRecordsConverter;

impl
    CrudConverter<
        entity::settlement_records::Entity,
        SettlementRecordCreate,
        SettlementRecordUpdate,
    > for SettlementRecordsConverter
{
    fn create_to_active_model(
        &self,
        data: SettlementRecordCreate,
    ) -> MijiResult<entity::settlement_records::ActiveModel> {
        entity::settlement_records::ActiveModel::try_from(data)
            .map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::settlement_records::Model,
        data: SettlementRecordUpdate,
    ) -> MijiResult<entity::settlement_records::ActiveModel> {
        let mut active_model = entity::settlement_records::ActiveModel {
            serial_num: ActiveValue::Set(model.serial_num.clone()),
            family_ledger_serial_num: ActiveValue::Set(model.family_ledger_serial_num.clone()),
            initiated_by: ActiveValue::Set(model.initiated_by.clone()),
            created_at: ActiveValue::Set(model.created_at),
            ..Default::default()
        };

        data.apply_to_model(&mut active_model);
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::settlement_records::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "settlement_records"
    }
}

#[async_trait]
impl LocalizableConverter<entity::settlement_records::Model> for SettlementRecordsConverter {
    async fn model_with_local(
        &self,
        model: entity::settlement_records::Model,
    ) -> MijiResult<entity::settlement_records::Model> {
        Ok(model.to_local())
    }
}

pub struct SettlementRecordsService {
    inner: GenericCrudService<
        entity::settlement_records::Entity,
        SettlementRecordsFilter,
        SettlementRecordCreate,
        SettlementRecordUpdate,
        SettlementRecordsConverter,
        SettlementRecordsHooks,
    >,
}

impl Default for SettlementRecordsService {
    fn default() -> Self {
        use std::sync::Arc;
        Self::new(
            SettlementRecordsConverter,
            SettlementRecordsHooks,
            Arc::new(NoopLogger),
        )
    }
}

impl SettlementRecordsService {
    pub fn new(
        converter: SettlementRecordsConverter,
        hooks: SettlementRecordsHooks,
        logger: std::sync::Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for SettlementRecordsService {
    type Target = GenericCrudService<
        entity::settlement_records::Entity,
        SettlementRecordsFilter,
        SettlementRecordCreate,
        SettlementRecordUpdate,
        SettlementRecordsConverter,
        SettlementRecordsHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl SettlementRecordsService {
    /// 根据家庭账本ID查询结算记录
    pub async fn find_by_family_ledger(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<Vec<SettlementRecordResponse>> {
        self.find_with_query(
            db,
            SettlementRecordQuery {
                family_ledger_serial_num: Some(family_ledger_serial_num.to_string()),
                ..Default::default()
            },
        )
        .await
        .map(|paged| paged.rows)
    }

    /// 根据查询条件获取结算记录
    pub async fn find_with_query(
        &self,
        db: &DbConn,
        query: SettlementRecordQuery,
    ) -> MijiResult<PagedResult<SettlementRecordResponse>> {
        let mut select = entity::settlement_records::Entity::find();

        // 应用查询条件
        if let Some(family_ledger_serial_num) = &query.family_ledger_serial_num {
            select = select.filter(
                entity::settlement_records::Column::FamilyLedgerSerialNum
                    .eq(family_ledger_serial_num),
            );
        }

        if let Some(settlement_type) = &query.settlement_type {
            select = select
                .filter(entity::settlement_records::Column::SettlementType.eq(settlement_type));
        }

        if let Some(status) = &query.status {
            select = select.filter(entity::settlement_records::Column::Status.eq(status));
        }

        if let Some(initiated_by) = &query.initiated_by {
            select =
                select.filter(entity::settlement_records::Column::InitiatedBy.eq(initiated_by));
        }

        if let Some(start_date) = query.start_date {
            select = select.filter(entity::settlement_records::Column::PeriodStart.gte(start_date));
        }

        if let Some(end_date) = query.end_date {
            select = select.filter(entity::settlement_records::Column::PeriodEnd.lte(end_date));
        }

        // 排序：创建时间降序
        select = select.order_by(entity::settlement_records::Column::CreatedAt, Order::Desc);

        let page = query.page.unwrap_or(1);
        let page_size = query.page_size.unwrap_or(20);

        // 简化分页实现
        let offset = (page - 1) * page_size;
        let models = select
            .limit(page_size)
            .offset(offset)
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        let total_count = if let Some(family_ledger_serial_num) = &query.family_ledger_serial_num {
            entity::settlement_records::Entity::find()
                .filter(
                    entity::settlement_records::Column::FamilyLedgerSerialNum
                        .eq(family_ledger_serial_num),
                )
                .count(db)
                .await
        } else {
            entity::settlement_records::Entity::find().count(db).await
        }
        .map_err(|e| {
            AppError::simple(
                common::BusinessCode::DatabaseError,
                format!("Database error: {}", e),
            )
        })? as u64;

        let responses: Vec<SettlementRecordResponse> = models
            .into_iter()
            .map(SettlementRecordResponse::from)
            .collect();

        Ok(PagedResult {
            rows: responses,
            total_count: total_count as usize,
            current_page: page as usize,
            page_size: page_size as usize,
            total_pages: total_count.div_ceil(page_size) as usize,
        })
    }

    /// 生成结算建议
    pub async fn generate_settlement_suggestion(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        period_start: NaiveDate,
        period_end: NaiveDate,
    ) -> MijiResult<SettlementSuggestion> {
        let debt_service = DebtRelationsService::default();
        let optimizer = SettlementOptimizer::new();

        // 获取所有成员的债务汇总
        let members = entity::family_member::Entity::find()
            .filter(entity::family_member::Column::Status.eq("Active"))
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        let mut member_summaries = Vec::new();
        for member in members {
            let summary = debt_service
                .get_member_debt_summary(db, family_ledger_serial_num, &member.serial_num)
                .await?;
            member_summaries.push(summary);
        }

        // 生成优化建议
        let suggestion = optimizer.generate_settlement_suggestion(
            member_summaries,
            family_ledger_serial_num.to_string(),
            period_start,
            period_end,
            "CNY".to_string(), // 默认货币
        )?;

        Ok(suggestion)
    }

    /// 创建结算记录
    pub async fn create_settlement_from_suggestion(
        &self,
        db: &DbConn,
        suggestion: SettlementSuggestion,
        initiated_by: &str,
        settlement_type: &str,
    ) -> MijiResult<SettlementRecordResponse> {
        let settlement_details =
            serde_json::to_value(&suggestion.settlement_details).map_err(|e| {
                AppError::simple(
                    common::BusinessCode::ValidationError,
                    format!("序列化结算详情失败: {}", e),
                )
            })?;

        let optimized_transfers =
            serde_json::to_value(&suggestion.optimized_transfers).map_err(|e| {
                AppError::simple(
                    common::BusinessCode::ValidationError,
                    format!("序列化转账建议失败: {}", e),
                )
            })?;

        let participant_members = serde_json::to_value(
            &suggestion
                .settlement_details
                .iter()
                .map(|d| &d.member_serial_num)
                .collect::<Vec<_>>(),
        )
        .map_err(|e| {
            AppError::simple(
                common::BusinessCode::ValidationError,
                format!("序列化参与成员失败: {}", e),
            )
        })?;

        let create_data = SettlementRecordCreate {
            settlement_type: settlement_type.to_string(),
            period_start: suggestion.period_start,
            period_end: suggestion.period_end,
            total_amount: suggestion.total_amount,
            currency: suggestion.currency,
            participant_members,
            settlement_details,
            optimized_transfers: Some(optimized_transfers),
            description: Some(format!(
                "系统生成的结算建议 - {} 个参与者，{} 笔转账",
                suggestion.participant_count, suggestion.transfer_count
            )),
            notes: None,
        };

        let mut active_model = SettlementRecordsConverter.create_to_active_model(create_data)?;
        active_model.family_ledger_serial_num =
            ActiveValue::Set(suggestion.family_ledger_serial_num);
        active_model.initiated_by = ActiveValue::Set(initiated_by.to_string());

        let settlement = entity::settlement_records::Entity::insert(active_model)
            .exec_with_returning(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(SettlementRecordResponse::from(settlement))
    }

    /// 完成结算
    pub async fn complete_settlement(
        &self,
        db: &DbConn,
        complete_request: CompleteSettlement,
        completed_by: &str,
    ) -> MijiResult<SettlementRecordResponse> {
        let settlement =
            entity::settlement_records::Entity::find_by_id(&complete_request.settlement_serial_num)
                .one(db)
                .await
                .map_err(|e| {
                    AppError::simple(
                        common::BusinessCode::DatabaseError,
                        format!("Database error: {}", e),
                    )
                })?
                .ok_or_else(|| {
                    AppError::simple(common::BusinessCode::NotFound, "结算记录不存在")
                })?;

        if settlement.status != "Pending" && settlement.status != "InProgress" {
            return Err(AppError::simple(
                common::BusinessCode::ValidationError,
                "只能完成待处理或进行中的结算",
            ));
        }

        let update_data = SettlementRecordUpdate {
            status: Some("Completed".to_string()),
            optimized_transfers: None,
            description: None,
            notes: complete_request.completion_notes,
        };

        let mut active_model =
            SettlementRecordsConverter.update_to_active_model(settlement, update_data)?;
        active_model.completed_by = ActiveValue::Set(Some(completed_by.to_string()));

        let updated_settlement = entity::settlement_records::Entity::update(active_model)
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 完成结算后，将相关债务标记为已结算
        self.settle_related_debts(db, &complete_request.settlement_serial_num)
            .await?;

        Ok(SettlementRecordResponse::from(updated_settlement))
    }

    /// 取消结算
    pub async fn cancel_settlement(
        &self,
        db: &DbConn,
        cancel_request: CancelSettlement,
    ) -> MijiResult<SettlementRecordResponse> {
        let settlement =
            entity::settlement_records::Entity::find_by_id(&cancel_request.settlement_serial_num)
                .one(db)
                .await
                .map_err(|e| {
                    AppError::simple(
                        common::BusinessCode::DatabaseError,
                        format!("Database error: {}", e),
                    )
                })?
                .ok_or_else(|| {
                    AppError::simple(common::BusinessCode::NotFound, "结算记录不存在")
                })?;

        if settlement.status == "Completed" {
            return Err(AppError::simple(
                common::BusinessCode::ValidationError,
                "已完成的结算不能取消",
            ));
        }

        let update_data = SettlementRecordUpdate {
            status: Some("Cancelled".to_string()),
            optimized_transfers: None,
            description: None,
            notes: cancel_request.cancellation_reason,
        };

        let active_model =
            SettlementRecordsConverter.update_to_active_model(settlement, update_data)?;

        let updated_settlement = entity::settlement_records::Entity::update(active_model)
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(SettlementRecordResponse::from(updated_settlement))
    }

    /// 获取结算统计
    pub async fn get_settlement_statistics(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<SettlementStats> {
        let settlements = entity::settlement_records::Entity::find()
            .filter(
                entity::settlement_records::Column::FamilyLedgerSerialNum
                    .eq(family_ledger_serial_num),
            )
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        let total_settlements = settlements.len() as i64;
        let pending_settlements =
            settlements.iter().filter(|s| s.status == "Pending").count() as i64;
        let completed_settlements = settlements
            .iter()
            .filter(|s| s.status == "Completed")
            .count() as i64;
        let cancelled_settlements = settlements
            .iter()
            .filter(|s| s.status == "Cancelled")
            .count() as i64;

        let total_amount: Decimal = settlements.iter().map(|s| s.total_amount).sum();
        let completed_amount: Decimal = settlements
            .iter()
            .filter(|s| s.status == "Completed")
            .map(|s| s.total_amount)
            .sum();

        Ok(SettlementStats {
            total_settlements,
            pending_settlements,
            completed_settlements,
            cancelled_settlements,
            total_amount,
            completed_amount,
        })
    }

    /// 自动结算检查
    pub async fn check_auto_settlement(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        config: &AutoSettlementConfig,
    ) -> MijiResult<Option<SettlementSuggestion>> {
        if !config.enabled {
            return Ok(None);
        }

        // 计算结算周期
        let now = chrono::Utc::now().date_naive();
        let (period_start, period_end) = match config.settlement_cycle.as_str() {
            "Weekly" => {
                let days_since_monday = now.weekday().num_days_from_monday();
                let period_start = now - chrono::Duration::days(days_since_monday as i64);
                let period_end = period_start + chrono::Duration::days(6);
                (period_start, period_end)
            }
            "Monthly" => {
                let period_start =
                    NaiveDate::from_ymd_opt(now.year(), now.month(), 1).ok_or_else(|| {
                        AppError::simple(common::BusinessCode::ValidationError, "无效的日期")
                    })?;
                let period_end = if now.month() == 12 {
                    NaiveDate::from_ymd_opt(now.year() + 1, 1, 1)
                } else {
                    NaiveDate::from_ymd_opt(now.year(), now.month() + 1, 1)
                }
                .ok_or_else(|| {
                    AppError::simple(common::BusinessCode::ValidationError, "无效的日期")
                })? - chrono::Duration::days(1);
                (period_start, period_end)
            }
            "Quarterly" => {
                let quarter_start_month = ((now.month() - 1) / 3) * 3 + 1;
                let period_start = NaiveDate::from_ymd_opt(now.year(), quarter_start_month, 1)
                    .ok_or_else(|| {
                        AppError::simple(common::BusinessCode::ValidationError, "无效的日期")
                    })?;
                let period_end = if quarter_start_month + 2 == 12 {
                    NaiveDate::from_ymd_opt(now.year() + 1, 1, 1)
                } else {
                    NaiveDate::from_ymd_opt(now.year(), quarter_start_month + 3, 1)
                }
                .ok_or_else(|| {
                    AppError::simple(common::BusinessCode::ValidationError, "无效的日期")
                })? - chrono::Duration::days(1);
                (period_start, period_end)
            }
            _ => return Ok(None),
        };

        // 生成结算建议
        let suggestion = self
            .generate_settlement_suggestion(db, family_ledger_serial_num, period_start, period_end)
            .await?;

        // 检查是否达到最小金额阈值
        if suggestion.total_amount < config.min_amount_threshold {
            return Ok(None);
        }

        Ok(Some(suggestion))
    }

    /// 结算相关债务
    async fn settle_related_debts(
        &self,
        db: &DbConn,
        settlement_serial_num: &str,
    ) -> MijiResult<()> {
        // 获取结算记录
        let settlement = entity::settlement_records::Entity::find_by_id(settlement_serial_num)
            .one(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "结算记录不存在"))?;

        // 获取参与成员
        let participant_members: Vec<String> =
            serde_json::from_value(settlement.participant_members).map_err(|e| {
                AppError::simple(
                    common::BusinessCode::ValidationError,
                    format!("解析参与成员失败: {}", e),
                )
            })?;

        // 将这些成员之间的债务标记为已结算
        let now = DateUtils::local_now();

        entity::debt_relations::Entity::update_many()
            .col_expr(
                entity::debt_relations::Column::Status,
                sea_orm::sea_query::Expr::value("Settled"),
            )
            .col_expr(
                entity::debt_relations::Column::SettledAt,
                sea_orm::sea_query::Expr::value(now),
            )
            .filter(
                Condition::all()
                    .add(
                        entity::debt_relations::Column::FamilyLedgerSerialNum
                            .eq(&settlement.family_ledger_serial_num),
                    )
                    .add(
                        entity::debt_relations::Column::CreditorMemberSerialNum
                            .is_in(&participant_members),
                    )
                    .add(
                        entity::debt_relations::Column::DebtorMemberSerialNum
                            .is_in(&participant_members),
                    )
                    .add(entity::debt_relations::Column::Status.eq("Active")),
            )
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(())
    }

    /// 获取历史结算趋势
    pub async fn get_settlement_trends(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        months: i32,
    ) -> MijiResult<Vec<(String, i64, Decimal)>> {
        let start_date =
            chrono::Utc::now().date_naive() - chrono::Duration::days((months * 30) as i64);

        let settlements = entity::settlement_records::Entity::find()
            .filter(
                Condition::all()
                    .add(
                        entity::settlement_records::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(entity::settlement_records::Column::CreatedAt.gte(start_date))
                    .add(entity::settlement_records::Column::Status.eq("Completed")),
            )
            .order_by(entity::settlement_records::Column::CreatedAt, Order::Asc)
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 按月分组统计
        let mut monthly_stats: HashMap<String, (i64, Decimal)> = HashMap::new();

        for settlement in settlements {
            let month_key = settlement.created_at.format("%Y-%m").to_string();
            let (count, amount) = monthly_stats.entry(month_key).or_insert((0, Decimal::ZERO));
            *count += 1;
            *amount += settlement.total_amount;
        }

        let mut trends: Vec<(String, i64, Decimal)> = monthly_stats
            .into_iter()
            .map(|(month, (count, amount))| (month, count, amount))
            .collect();

        trends.sort_by(|a, b| a.0.cmp(&b.0));

        Ok(trends)
    }
}
