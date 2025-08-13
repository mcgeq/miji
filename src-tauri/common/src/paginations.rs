use sea_orm::sea_query::Expr;
use sea_orm::{ColumnTrait, Condition, EntityTrait, Order, QueryOrder, Select};
use serde::{Deserialize, Serialize};
use std::str::FromStr;
use validator::Validate;

/// 分页查询参数
#[derive(Debug, Clone, Deserialize, Validate)]
pub struct PagedQuery<F> {
    /// 当前页码（从 1 开始）
    #[serde(default = "default_current_page")]
    pub current_page: usize,

    /// 每页数量
    #[serde(default = "default_page_size")]
    #[validate(range(min = 1, max = 100))]
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
#[derive(Clone, Debug, Deserialize)]
pub struct DateRange {
    pub start: Option<String>,
    pub end: Option<String>,
}

/// 排序方向
#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
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
pub struct SortOptions {
    /// 自定义排序 SQL
    #[serde(rename = "customOrderBy")]
    pub custom_order_by: Option<String>,

    /// 排序字段
    #[serde(rename = "sortBy")]
    pub sort_by: Option<String>,
    /// 是否降序
    pub desc: bool,
    /// 排序方向
    #[serde(rename = "sortDir")]
    pub sort_dir: Option<SortDirection>,
}

/// 分页结果
#[derive(Debug, Serialize)]
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
        match self {
            SortOptions {
                custom_order_by: Some(order_by),
                sort_dir,
                ..
            } => {
                let direction = sort_dir.unwrap_or(SortDirection::Asc).into();
                // 使用 Expr::cust 创建自定义表达式并通过 order_by 应用
                query.order_by(Expr::cust(order_by), direction)
            }
            SortOptions {
                sort_by: Some(field),
                sort_dir,
                ..
            } => {
                if let Ok(column) = E::Column::from_str(field) {
                    let direction = sort_dir.unwrap_or(SortDirection::Asc).into();
                    query.order_by(column, direction)
                } else {
                    query
                }
            }
            _ => query,
        }
    }
}
