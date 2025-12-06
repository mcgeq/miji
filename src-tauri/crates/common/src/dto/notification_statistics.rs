use chrono::{DateTime, FixedOffset};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// 通知统计基础信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationStatistics {
    /// 总通知数
    pub total: i64,
    /// 成功发送数
    pub success: i64,
    /// 失败数
    pub failed: i64,
    /// 待发送数
    pub pending: i64,
    /// 按类型统计
    pub by_type: HashMap<String, i64>,
    /// 按优先级统计
    pub by_priority: HashMap<String, i64>,
}

/// 统计查询参数
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StatisticsQuery {
    /// 时间范围（天数）：7d, 30d, 90d
    pub period: String,
    /// 用户ID（可选，用于按用户筛选）
    pub user_id: Option<String>,
}

/// 每日趋势数据点
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyTrend {
    /// 日期
    pub date: DateTime<FixedOffset>,
    /// 成功数
    pub success: i64,
    /// 失败数
    pub failed: i64,
}

/// 扩展的统计信息（包含趋势数据）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationStatisticsExtended {
    /// 基础统计
    #[serde(flatten)]
    pub base: NotificationStatistics,
    /// 每日趋势
    pub daily_trend: Vec<DailyTrend>,
}

impl Default for NotificationStatistics {
    fn default() -> Self {
        Self {
            total: 0,
            success: 0,
            failed: 0,
            pending: 0,
            by_type: HashMap::new(),
            by_priority: HashMap::new(),
        }
    }
}
