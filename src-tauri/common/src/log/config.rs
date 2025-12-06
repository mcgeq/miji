use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// 日志目标
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LogTarget {
    Console,
    File,
    Database,
}

/// 日志级别
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LogLevel {
    Error,
    Warn,
    Info,
    Debug,
    Trace,
}

impl Default for LogLevel {
    fn default() -> Self {
        LogLevel::Info
    }
}

/// 日志过滤器配置
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct LogFilterConfig {
    /// 日志级别
    pub level: LogLevel,
    /// 日志目标
    pub targets: Vec<LogTarget>,
    /// 包含的表
    pub include_tables: Option<Vec<String>>,
    /// 排除的表
    pub exclude_tables: Option<Vec<String>>,
}

/// 日志配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggingConfig {
    /// 是否启用控制台日志
    #[serde(default)]
    pub console: bool,
    /// 是否启用文件日志
    #[serde(default)]
    pub file: bool,
    /// 是否启用数据库日志
    #[serde(default = "default_true")]
    pub database: bool,
    /// 文件日志路径
    #[serde(default)]
    pub file_path: Option<PathBuf>,
    /// 日志文件最大大小 (MB)
    #[serde(default = "default_max_file_size")]
    pub max_file_size: u64,
    /// 日志文件保留数量
    #[serde(default = "default_max_files")]
    pub max_files: u32,
    /// 是否在事务中记录关键日志
    #[serde(default = "default_true")]
    pub transactional_logging: bool,
    /// 是否异步记录非关键字段
    #[serde(default = "default_true")]
    pub async_metadata: bool,
}

fn default_true() -> bool {
    true
}
fn default_max_file_size() -> u64 {
    100
} // 100MB
fn default_max_files() -> u32 {
    10
} // 保留 10 个日志文件

impl Default for LoggingConfig {
    fn default() -> Self {
        Self {
            console: false,
            file: false,
            database: true,
            file_path: None,
            max_file_size: default_max_file_size(),
            max_files: default_max_files(),
            transactional_logging: true,
            async_metadata: true,
        }
    }
}
