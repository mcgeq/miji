use serde::{Deserialize, Serialize};

/// 数据迁移结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MigrationResult {
    /// 成功迁移的记录数
    pub success_count: usize,
    /// 失败的记录数
    pub error_count: usize,
    /// 跳过的记录数（已存在）
    pub skipped_count: usize,
    /// 错误信息列表
    pub errors: Vec<String>,
    /// 迁移耗时（毫秒）
    pub duration_ms: u128,
}

impl MigrationResult {
    pub fn new() -> Self {
        Self {
            success_count: 0,
            error_count: 0,
            skipped_count: 0,
            errors: Vec::new(),
            duration_ms: 0,
        }
    }
}

impl Default for MigrationResult {
    fn default() -> Self {
        Self::new()
    }
}
