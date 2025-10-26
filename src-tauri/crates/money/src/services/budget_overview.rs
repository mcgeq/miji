use std::collections::HashMap;

use chrono::{DateTime, FixedOffset};
use common::{error::MijiResult, utils::date::DateUtils};
use sea_orm::{
    ColumnTrait, Condition, DatabaseConnection, EntityTrait, QueryFilter, prelude::Decimal,
};
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

/// 预算总览统计响应
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetOverviewSummary {
    /// 总预算金额
    pub total_budget_amount: Decimal,
    /// 已使用金额（当前周期）
    pub used_amount: Decimal,
    /// 剩余金额
    pub remaining_amount: Decimal,
    /// 预算完成率（百分比）
    pub completion_rate: Decimal,
    /// 超预算金额
    pub over_budget_amount: Decimal,
    /// 预算数量
    pub budget_count: i32,
    /// 超预算数量
    pub over_budget_count: i32,
    /// 货币
    pub currency: String,
    /// 计算时间
    pub calculated_at: DateTime<FixedOffset>,
}

/// 预算总览请求参数
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetOverviewRequest {
    /// 基础货币
    pub base_currency: String,
    /// 计算日期（可选，默认为当前时间）
    pub calculation_date: Option<DateTime<FixedOffset>>,
    /// 是否包含非激活预算（可选，默认为false）
    pub include_inactive: Option<bool>,
}

impl Default for BudgetOverviewRequest {
    fn default() -> Self {
        Self {
            base_currency: "CNY".to_string(),
            calculation_date: None,
            include_inactive: Some(false),
        }
    }
}

/// 预算总览服务
pub struct BudgetOverviewService;

impl BudgetOverviewService {
    /// 计算预算总览
    pub async fn calculate_overview(
        db: &DatabaseConnection,
        request: BudgetOverviewRequest,
    ) -> MijiResult<BudgetOverviewSummary> {
        let calculation_date = request
            .calculation_date
            .unwrap_or_else(DateUtils::local_now);

        info!(
            "开始计算预算总览，货币: {}, 计算日期: {}",
            request.base_currency, calculation_date
        );

        // 构建基础查询条件
        let mut condition = Condition::all()
            .add(entity::budget::Column::Currency.eq(&request.base_currency))
            .add(entity::budget::Column::StartDate.lte(calculation_date))
            .add(entity::budget::Column::EndDate.gte(calculation_date));

        // 是否包含非激活预算
        if !request.include_inactive.unwrap_or(false) {
            condition = condition.add(entity::budget::Column::IsActive.eq(true));
        }

        debug!(
            "查询条件: 货币={}, 开始日期<={}, 结束日期>={}, 激活状态={}",
            request.base_currency,
            calculation_date,
            calculation_date,
            !request.include_inactive.unwrap_or(false)
        );

        // 查询符合条件的预算
        let budgets = entity::budget::Entity::find()
            .filter(condition)
            .all(db)
            .await?;

        info!("查询到 {} 个预算", budgets.len());

        if budgets.is_empty() {
            warn!("没有找到符合条件的预算");
            return Ok(BudgetOverviewSummary {
                total_budget_amount: Decimal::ZERO,
                used_amount: Decimal::ZERO,
                remaining_amount: Decimal::ZERO,
                completion_rate: Decimal::ZERO,
                over_budget_amount: Decimal::ZERO,
                budget_count: 0,
                over_budget_count: 0,
                currency: request.base_currency,
                calculated_at: calculation_date,
            });
        }

        // 计算各项指标
        let mut total_budget_amount = Decimal::ZERO;
        let mut total_used_amount = Decimal::ZERO;
        let mut over_budget_count = 0;
        let mut over_budget_amount = Decimal::ZERO;

        for budget in &budgets {
            let budget_amount = budget.amount;
            let used_amount = budget.current_period_used;

            debug!(
                "预算: {}, 总金额: {}, 已使用: {}",
                budget.name, budget_amount, used_amount
            );

            total_budget_amount += budget_amount;
            total_used_amount += used_amount;

            // 检查是否超预算
            if used_amount > budget_amount {
                over_budget_count += 1;
                over_budget_amount += used_amount - budget_amount;
            }
        }

        // 计算剩余金额
        let remaining_amount = if total_used_amount <= total_budget_amount {
            total_budget_amount - total_used_amount
        } else {
            Decimal::ZERO
        };

        // 计算完成率
        let completion_rate = if total_budget_amount.is_zero() {
            Decimal::ZERO
        } else {
            ((total_used_amount / total_budget_amount) * Decimal::from(100)).round_dp(2)
        };

        info!(
            "预算总览计算结果: 总预算={}, 已使用={}, 剩余={}, 完成率={}%",
            total_budget_amount, total_used_amount, remaining_amount, completion_rate
        );

        Ok(BudgetOverviewSummary {
            total_budget_amount,
            used_amount: total_used_amount,
            remaining_amount,
            completion_rate,
            over_budget_amount,
            budget_count: budgets.len() as i32,
            over_budget_count,
            currency: request.base_currency,
            calculated_at: calculation_date,
        })
    }

    /// 按预算类型分组计算
    pub async fn calculate_by_budget_type(
        db: &DatabaseConnection,
        request: BudgetOverviewRequest,
    ) -> MijiResult<HashMap<String, BudgetOverviewSummary>> {
        let calculation_date = request
            .calculation_date
            .unwrap_or_else(DateUtils::local_now);

        // 构建基础查询条件
        let mut condition = Condition::all()
            .add(entity::budget::Column::Currency.eq(&request.base_currency))
            .add(entity::budget::Column::StartDate.lte(calculation_date))
            .add(entity::budget::Column::EndDate.gte(calculation_date));

        if !request.include_inactive.unwrap_or(false) {
            condition = condition.add(entity::budget::Column::IsActive.eq(true));
        }

        // 查询符合条件的预算
        let budgets = entity::budget::Entity::find()
            .filter(condition)
            .all(db)
            .await?;

        let mut type_summaries: HashMap<String, BudgetOverviewSummary> = HashMap::new();

        for budget in budgets {
            let budget_type = budget.budget_type.clone();
            let summary =
                type_summaries
                    .entry(budget_type)
                    .or_insert_with(|| BudgetOverviewSummary {
                        total_budget_amount: Decimal::ZERO,
                        used_amount: Decimal::ZERO,
                        remaining_amount: Decimal::ZERO,
                        completion_rate: Decimal::ZERO,
                        over_budget_amount: Decimal::ZERO,
                        budget_count: 0,
                        over_budget_count: 0,
                        currency: request.base_currency.clone(),
                        calculated_at: calculation_date,
                    });

            let budget_amount = budget.amount;
            let used_amount = budget.current_period_used;

            summary.total_budget_amount += budget_amount;
            summary.used_amount += used_amount;
            summary.budget_count += 1;

            // 检查是否超预算
            if used_amount > budget_amount {
                summary.over_budget_count += 1;
                summary.over_budget_amount += used_amount - budget_amount;
            }
        }

        // 计算每个类型的剩余金额和完成率
        for summary in type_summaries.values_mut() {
            summary.remaining_amount = if summary.used_amount <= summary.total_budget_amount {
                summary.total_budget_amount - summary.used_amount
            } else {
                Decimal::ZERO
            };

            summary.completion_rate = if summary.total_budget_amount.is_zero() {
                Decimal::ZERO
            } else {
                ((summary.used_amount / summary.total_budget_amount) * Decimal::from(100))
                    .round_dp(2)
            };
        }

        Ok(type_summaries)
    }

    /// 按预算范围类型分组计算
    pub async fn calculate_by_scope_type(
        db: &DatabaseConnection,
        request: BudgetOverviewRequest,
    ) -> MijiResult<HashMap<String, BudgetOverviewSummary>> {
        let calculation_date = request
            .calculation_date
            .unwrap_or_else(DateUtils::local_now);

        // 构建基础查询条件
        let mut condition = Condition::all()
            .add(entity::budget::Column::Currency.eq(&request.base_currency))
            .add(entity::budget::Column::StartDate.lte(calculation_date))
            .add(entity::budget::Column::EndDate.gte(calculation_date));

        if !request.include_inactive.unwrap_or(false) {
            condition = condition.add(entity::budget::Column::IsActive.eq(true));
        }

        // 查询符合条件的预算
        let budgets = entity::budget::Entity::find()
            .filter(condition)
            .all(db)
            .await?;

        let mut scope_summaries: HashMap<String, BudgetOverviewSummary> = HashMap::new();

        for budget in budgets {
            let scope_type = budget.budget_scope_type.clone();
            let summary =
                scope_summaries
                    .entry(scope_type)
                    .or_insert_with(|| BudgetOverviewSummary {
                        total_budget_amount: Decimal::ZERO,
                        used_amount: Decimal::ZERO,
                        remaining_amount: Decimal::ZERO,
                        completion_rate: Decimal::ZERO,
                        over_budget_amount: Decimal::ZERO,
                        budget_count: 0,
                        over_budget_count: 0,
                        currency: request.base_currency.clone(),
                        calculated_at: calculation_date,
                    });

            let budget_amount = budget.amount;
            let used_amount = budget.current_period_used;

            summary.total_budget_amount += budget_amount;
            summary.used_amount += used_amount;
            summary.budget_count += 1;

            // 检查是否超预算
            if used_amount > budget_amount {
                summary.over_budget_count += 1;
                summary.over_budget_amount += used_amount - budget_amount;
            }
        }

        // 计算每个范围的剩余金额和完成率
        for summary in scope_summaries.values_mut() {
            summary.remaining_amount = if summary.used_amount <= summary.total_budget_amount {
                summary.total_budget_amount - summary.used_amount
            } else {
                Decimal::ZERO
            };

            summary.completion_rate = if summary.total_budget_amount.is_zero() {
                Decimal::ZERO
            } else {
                ((summary.used_amount / summary.total_budget_amount) * Decimal::from(100))
                    .round_dp(2)
            };
        }

        Ok(scope_summaries)
    }
}
