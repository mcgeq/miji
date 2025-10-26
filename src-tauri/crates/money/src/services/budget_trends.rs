use std::collections::HashMap;

use chrono::{DateTime, Datelike, FixedOffset, NaiveDate};
use common::{error::MijiResult, utils::date::DateUtils};
use sea_orm::{
    ColumnTrait, Condition, DatabaseConnection, EntityTrait, QueryFilter, QueryOrder, QuerySelect,
    prelude::Decimal,
};
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

use entity::budget;

/// 预算趋势数据
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetTrendData {
    /// 时间段（如：2024-01, 2024-W01）
    pub period: String,
    /// 总预算金额
    pub total_budget: Decimal,
    /// 已使用金额
    pub used_amount: Decimal,
    /// 剩余金额
    pub remaining_amount: Decimal,
    /// 完成率（百分比）
    pub completion_rate: Decimal,
}

/// 预算趋势请求参数
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetTrendRequest {
    /// 开始日期
    pub start_date: DateTime<FixedOffset>,
    /// 结束日期
    pub end_date: DateTime<FixedOffset>,
    /// 时间周期类型（month, week）
    pub period_type: String,
    /// 基础货币
    pub base_currency: String,
    /// 是否包含非激活预算
    pub include_inactive: Option<bool>,
}

/// 预算分类统计数据
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetCategoryStats {
    /// 分类名称
    pub category: String,
    /// 预算数量
    pub budget_count: i32,
    /// 总预算金额
    pub total_budget: Decimal,
    /// 已使用金额
    pub used_amount: Decimal,
    /// 平均完成率
    pub average_completion_rate: Decimal,
}

/// 预算趋势分析服务
pub struct BudgetTrendService;

impl BudgetTrendService {
    /// 获取预算趋势数据
    pub async fn get_budget_trends(
        db: &DatabaseConnection,
        request: BudgetTrendRequest,
    ) -> MijiResult<Vec<BudgetTrendData>> {
        info!("开始获取预算趋势数据: {:?}", request);

        // 构建查询条件
        let mut condition = Condition::all();

        // 日期范围过滤
        condition = condition.add(budget::Column::StartDate.lte(request.end_date));
        condition = condition.add(budget::Column::EndDate.gte(request.start_date));

        // 激活状态过滤
        if !request.include_inactive.unwrap_or(false) {
            condition = condition.add(budget::Column::IsActive.eq(true));
        }

        // 查询预算数据
        let budgets = budget::Entity::find().filter(condition).all(db).await?;

        info!("查询到 {} 个预算", budgets.len());

        if budgets.is_empty() {
            warn!("没有找到符合条件的预算");
            return Ok(vec![]);
        }

        // 根据周期类型生成趋势数据
        let mut trends = Vec::new();
        let mut current_date = request.start_date.date_naive();

        while current_date <= request.end_date.date_naive() {
            let period = match request.period_type.as_str() {
                "month" => {
                    let next_month = if current_date.month() == 12 {
                        NaiveDate::from_ymd_opt(current_date.year() + 1, 1, 1).unwrap()
                    } else {
                        NaiveDate::from_ymd_opt(current_date.year(), current_date.month() + 1, 1)
                            .unwrap()
                    };
                    let period_end = next_month.pred_opt().unwrap_or(current_date);

                    // 计算这个月的统计数据
                    let month_stats =
                        Self::calculate_period_stats(&budgets, current_date, period_end);

                    trends.push(BudgetTrendData {
                        period: format!("{}-{:02}", current_date.year(), current_date.month()),
                        total_budget: month_stats.0,
                        used_amount: month_stats.1,
                        remaining_amount: month_stats.2,
                        completion_rate: month_stats.3,
                    });

                    next_month
                }
                "week" => {
                    let week_end = current_date + chrono::Duration::days(6);

                    // 计算这周的统计数据
                    let week_stats = Self::calculate_period_stats(&budgets, current_date, week_end);

                    let week_num = current_date.iso_week().week();
                    trends.push(BudgetTrendData {
                        period: format!("{}-W{:02}", current_date.year(), week_num),
                        total_budget: week_stats.0,
                        used_amount: week_stats.1,
                        remaining_amount: week_stats.2,
                        completion_rate: week_stats.3,
                    });

                    current_date + chrono::Duration::days(7)
                }
                _ => {
                    warn!("不支持的周期类型: {}", request.period_type);
                    break;
                }
            };

            current_date = period;
        }

        info!("生成 {} 个趋势数据点", trends.len());
        Ok(trends)
    }

    /// 获取预算分类统计
    pub async fn get_budget_category_stats(
        db: &DatabaseConnection,
        _base_currency: String,
        include_inactive: Option<bool>,
    ) -> MijiResult<Vec<BudgetCategoryStats>> {
        info!("开始获取预算分类统计");

        // 构建查询条件
        let mut condition = Condition::all();

        // 激活状态过滤
        if !include_inactive.unwrap_or(false) {
            condition = condition.add(budget::Column::IsActive.eq(true));
        }

        // 查询预算数据
        let budgets = budget::Entity::find().filter(condition).all(db).await?;

        info!("查询到 {} 个预算", budgets.len());

        if budgets.is_empty() {
            warn!("没有找到符合条件的预算");
            return Ok(vec![]);
        }

        // 按分类统计
        let mut category_map: HashMap<String, (i32, Decimal, Decimal)> = HashMap::new();

        for budget in &budgets {
            // 获取分类范围
            if let Some(category_scope) = &budget.category_scope {
                // 尝试解析 JSON 数组
                if let Ok(categories) =
                    serde_json::from_value::<Vec<String>>(category_scope.clone())
                {
                    if categories.is_empty() {
                        continue;
                    }

                    for category in categories {
                        let entry = category_map.entry(category).or_insert((
                            0,
                            Decimal::ZERO,
                            Decimal::ZERO,
                        ));
                        entry.0 += 1; // 预算数量
                        entry.1 += budget.amount; // 总预算
                        entry.2 += budget.current_period_used; // 已使用
                    }
                }
            }
        }

        // 转换为结果格式
        let mut stats = Vec::new();
        for (category, (count, total_budget, used_amount)) in category_map {
            let _remaining_amount = if used_amount <= total_budget {
                total_budget - used_amount
            } else {
                Decimal::ZERO
            };

            let completion_rate = if total_budget > Decimal::ZERO {
                (used_amount / total_budget) * Decimal::from(100)
            } else {
                Decimal::ZERO
            };

            stats.push(BudgetCategoryStats {
                category,
                budget_count: count,
                total_budget,
                used_amount,
                average_completion_rate: completion_rate,
            });
        }

        // 按总预算金额排序
        stats.sort_by(|a, b| b.total_budget.cmp(&a.total_budget));

        info!("生成 {} 个分类统计数据", stats.len());
        Ok(stats)
    }

    /// 计算指定时间段的统计数据
    fn calculate_period_stats(
        budgets: &[budget::Model],
        start_date: NaiveDate,
        end_date: NaiveDate,
    ) -> (Decimal, Decimal, Decimal, Decimal) {
        let mut total_budget = Decimal::ZERO;
        let mut total_used = Decimal::ZERO;

        for budget in budgets {
            // 检查预算是否在指定时间段内有效
            let budget_start = budget.start_date.date_naive();
            let budget_end = budget.end_date.date_naive();

            if budget_start <= end_date && budget_end >= start_date {
                total_budget += budget.amount;
                total_used += budget.current_period_used;
            }
        }

        let remaining_amount = if total_used <= total_budget {
            total_budget - total_used
        } else {
            Decimal::ZERO
        };

        let completion_rate = if total_budget > Decimal::ZERO {
            (total_used / total_budget) * Decimal::from(100)
        } else {
            Decimal::ZERO
        };

        (total_budget, total_used, remaining_amount, completion_rate)
    }
}
