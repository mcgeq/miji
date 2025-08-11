use chrono::{Local, LocalResult, NaiveDate, TimeZone};
use common::error::{AppError, CommonError, MijiResult};
use snafu::GenerateImplicitData;
use std::fs;
use std::path::PathBuf;

/// 日志文件管理器（负责目录创建、旧日志清理）
pub struct LogManager {
    root_dir: PathBuf,
    max_days: i64,
}

impl LogManager {
    /// 创建新的日志管理器
    pub fn new(root_dir: PathBuf, max_days: i64) -> Self {
        Self { root_dir, max_days }
    }

    /// 获取当天日志目录路径（格式：YYYY-MM-DD）
    pub fn today_log_dir(&self, segments: &[&str]) -> Result<PathBuf, AppError> {
        let today = Local::now();
        let date_dir = today.format("%Y-%m-%d").to_string();
        let mut path = self.root_dir.join(segments.join("/"));
        path.push(date_dir);

        // 手动处理错误并包装为 AppError
        fs::create_dir_all(&path).map_err(|_| {
            AppError::simple(
                common::BusinessCode::FileError,
                path.to_string_lossy().to_string(),
            )
        })?;

        Ok(path)
    }

    /// 清理超过保留天数的旧日志目录
    pub fn cleanup_old_logs(&self) -> MijiResult<()> {
        let threshold = Local::now() - chrono::Duration::days(self.max_days);
        let log_root = self.root_dir.join("logs");

        if !log_root.exists() {
            return Ok(());
        }

        for entry in fs::read_dir(&log_root)? {
            let entry = entry.map_err(|e| CommonError::File {
                path: log_root.display().to_string(),
                source: e,
                backtrace: snafu::Backtrace::generate(),
            })?;
            let path = entry.path();
            if path.is_dir() {
                let dir_name =
                    path.file_name()
                        .and_then(|n| n.to_str())
                        .ok_or_else(|| CommonError::File {
                            path: path.display().to_string(),
                            source: std::io::Error::new(
                                std::io::ErrorKind::InvalidData,
                                "Invalid directory name (non-UTF-8)",
                            ),
                            backtrace: snafu::Backtrace::generate(),
                        })?;

                // 解析目录名（格式：YYYY-MM-DD）
                let date = match NaiveDate::parse_from_str(dir_name, "%Y-%m-%d") {
                    Ok(d) => d,
                    Err(_) => {
                        // 非日期格式的目录跳过清理
                        tracing::debug!("Skipping non-date directory: {:?}", path);
                        continue;
                    }
                };

                // 转换为本地时间的 DateTime（取第一个匹配的时区）
                let local_result = Local.from_local_datetime(&date.and_hms_opt(0, 0, 0).unwrap());
                let local_datetime = match local_result {
                    LocalResult::Single(dt) => dt, // 唯一有效时间
                    LocalResult::Ambiguous(dt_early, _dt_late) => {
                        // 夏令时模糊时间，选择较早的时间（根据业务需求调整）
                        tracing::warn!(
                            "Ambiguous local time for directory {:?}, using earlier time: {}",
                            path,
                            dt_early
                        );
                        dt_early
                    }
                    LocalResult::None => {
                        // 无有效时间（理论上不会发生，因为目录名是合法日期）
                        return Err(CommonError::File {
                            path: path.display().to_string(),
                            source: std::io::Error::new(
                                std::io::ErrorKind::InvalidData,
                                "No valid local time for directory",
                            ),
                            backtrace: snafu::Backtrace::generate(),
                        }
                        .into());
                    }
                };
                // 比较并删除旧日志
                if local_datetime < threshold {
                    fs::remove_dir_all(&path).map_err(|e| CommonError::File {
                        path: path.display().to_string(),
                        source: e,
                        backtrace: snafu::Backtrace::generate(),
                    })?;
                    tracing::info!("Removed old log directory: {:?}", path);
                }
            }
        }

        Ok(())
    }
}
