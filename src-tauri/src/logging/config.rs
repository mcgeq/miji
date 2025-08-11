use common::{error::MijiResult, utils::files::MijiFiles};
use log::LevelFilter;
use serde::Deserialize;
use std::{env, path::PathBuf};

#[derive(Debug, Clone, Deserialize)]
pub struct LogConfig {
    /// 全局日志级别（默认：Info）
    #[serde(default = "default_level")]
    pub level: LevelFilter,
    /// 日志文件根目录（默认：MijiFiles::root_path()）
    #[serde(default = "default_root_dir")]
    pub root_dir: PathBuf,
    /// 日志保留天数（默认：30）
    #[serde(default = "default_max_days")]
    pub max_days: i64,
    /// 是否启用 JSON 格式（默认：false）
    #[serde(default = "default_enable_json")]
    pub enable_json: bool,
    /// 性能日志前缀（默认："perf::"）
    #[serde(default = "default_perf_prefix")]
    pub perf_prefix: String,
}

impl LogConfig {
    /// 从环境变量或默认值创建配置
    pub fn from_env() -> MijiResult<Self> {
        let level = env::var("MIJI_LOG_LEVEL")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or_else(default_level);

        Ok(Self {
            level,
            root_dir: env::var("MIJI_LOG_ROOT_DIR")
                .ok()
                .map(PathBuf::from)
                .unwrap_or_else(default_root_dir),
            max_days: env::var("MIJI_LOG_MAX_DAYS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or_else(default_max_days),
            enable_json: env::var("MIJI_LOG_JSON")
                .ok()
                .map(|s| s == "1" || s.eq_ignore_ascii_case("true"))
                .unwrap_or_else(default_enable_json),
            perf_prefix: env::var("MIJI_LOG_PERF_PREFIX")
                .ok()
                .unwrap_or_else(default_perf_prefix),
        })
    }
}

// 默认值辅助函数
fn default_level() -> LevelFilter {
    LevelFilter::Info
}

fn default_root_dir() -> PathBuf {
    let p = MijiFiles::root_path().unwrap();
    PathBuf::from(p)
}

fn default_max_days() -> i64 {
    30
}

fn default_enable_json() -> bool {
    false
}

fn default_perf_prefix() -> String {
    "perf::".to_string()
}
