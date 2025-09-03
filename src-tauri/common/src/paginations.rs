use sea_orm::sea_query::Expr;
use sea_orm::{ColumnTrait, Condition, EntityTrait, Iterable, Order, QueryOrder, Select};
use serde::{Deserialize, Serialize};
use std::str::FromStr;
use tracing::{error, info, warn};
use validator::Validate;

use crate::crud::service::sanitize_input;

/// 排序方向
#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum SortDirection {
    Asc,
    Desc,
}

impl From<SortDirection> for Order {
    fn from(direction: SortDirection) -> Self {
        match direction {
            SortDirection::Asc => Order::Asc,
            SortDirection::Desc => Order::Desc,
        }
    }
}

/// 排序选项
#[derive(Debug, Clone, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SortOptions {
    /// 自定义排序 SQL
    pub custom_order_by: Option<String>,
    /// 排序字段
    pub sort_by: Option<String>,
    /// 是否降序
    pub desc: bool,
    /// 排序方向
    pub sort_dir: Option<SortDirection>,
}

impl SortOptions {
    /// 获取排序字段，优先使用 sort_by，否则使用默认字段 "CreatedAt"
    fn effective_sort_field(&self) -> &str {
        self.sort_by.as_deref().unwrap_or("CreatedAt")
    }

    /// 获取排序方向，优先使用 sort_dir，其次使用 desc 字段
    fn effective_sort_direction(&self) -> Order {
        match self.sort_dir {
            Some(SortDirection::Asc) => Order::Asc,
            Some(SortDirection::Desc) => Order::Desc,
            None => {
                if self.desc {
                    Order::Desc
                } else {
                    Order::Asc
                }
            }
        }
    }
}

/// 排序 trait
pub trait Sortable<E: EntityTrait> {
    /// 应用排序
    fn apply_sort(&self, query: Select<E>) -> Select<E>;
}
// 为所有符合约束的类型实现 Sortable
impl<E> Sortable<E> for SortOptions
where
    E: EntityTrait,
    E::Column: ColumnTrait + FromStr,
{
    fn apply_sort(&self, query: Select<E>) -> Select<E> {
        info!("Applying sort options: {:?}", self);
        if let Some(order_by) = &self.custom_order_by {
            let direction = self.effective_sort_direction();
            return query.order_by(Expr::cust(order_by), direction);
        }

        // 获取有效的排序字段
        let sort_field = self.effective_sort_field();

        // 尝试解析为列枚举
        match E::Column::from_str(sort_field) {
            Ok(column) => {
                let direction = self.effective_sort_direction();
                query.order_by(column, direction)
            }
            Err(_) => {
                // 回退到默认排序：按创建时间降序
                warn!(
                    "Failed to parse sort field: {}, using default sort",
                    sort_field
                );
                if let Ok(created_at) = E::Column::from_str("created_at") {
                    query.order_by(created_at, Order::Desc)
                } else {
                    // 如果还没有，则使用第一个列
                    let mut columns = E::Column::iter();
                    if let Some(first_column) = columns.next() {
                        warn!("Using first column as fallback sort: {:?}", first_column);
                        query.order_by(first_column, Order::Desc)
                    } else {
                        error!("No columns available for sorting");
                        query
                    }
                }
            }
        }
    }
}

/// 分页查询参数
#[derive(Debug, Clone, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PagedQuery<F> {
    /// 当前页码（从 1 开始）
    #[serde(default = "default_current_page")]
    pub current_page: usize,

    /// 每页数量
    #[serde(default = "default_page_size")]
    #[validate(range(min = 4))]
    pub page_size: usize,

    /// 排序选项
    #[serde(default)]
    pub sort_options: SortOptions,

    /// 过滤条件
    #[serde(flatten)]
    pub filter: F,
}

fn default_current_page() -> usize {
    1
}

fn default_page_size() -> usize {
    20
}

/// 日期范围
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DateRange {
    pub start: Option<String>,
    pub end: Option<String>,
}

impl DateRange {
    pub fn to_condition<C: ColumnTrait>(&self, column: C) -> Condition {
        let mut condition = Condition::all();
        if let Some(start) = &self.start {
            condition = condition.add(column.gte(sanitize_input(start)));
        }
        if let Some(end) = &self.end {
            condition = condition.add(column.lte(sanitize_input(end)));
        }
        condition
    }
}

/// 分页结果
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PagedResult<T: Serialize> {
    pub rows: Vec<T>,
    pub total_count: usize,
    pub current_page: usize,
    pub page_size: usize,
    pub total_pages: usize,
}

/// 过滤 trait
pub trait Filter<E: EntityTrait> {
    /// 转换为查询条件
    fn to_condition(&self) -> Condition;
}
