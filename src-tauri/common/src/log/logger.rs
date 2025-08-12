use async_trait::async_trait;
use sea_orm::DatabaseTransaction;
use serde_json::Value;
use std::{path::PathBuf, sync::Arc};
use tokio::{fs::File, io::AsyncWriteExt, sync::Mutex};
use tracing::info;

use crate::{
    error::{AppError, MijiResult},
    log::config::{LogFilterConfig, LogTarget},
    utils::date::DateUtils,
};

/// 操作日志记录器 trait
#[async_trait]
pub trait OperationLogger: Send + Sync {
    /// 记录操作日志
    async fn log_operation(
        &self,
        operation: &str,
        target_table: &str,
        record_id: &str,
        data_before: Option<&Value>,
        data_after: Option<&Value>,
        tx: Option<&DatabaseTransaction>,
    ) -> MijiResult<()>;
}

/// 空操作日志记录器
pub struct NoopLogger;

#[async_trait]
impl OperationLogger for NoopLogger {
    async fn log_operation(
        &self,
        _operation: &str,
        _target_table: &str,
        _record_id: &str,
        _data_before: Option<&Value>,
        _data_after: Option<&Value>,
        _tx: Option<&DatabaseTransaction>,
    ) -> MijiResult<()> {
        Ok(())
    }
}

/// 控制台日志记录器
pub struct ConsoleLogger {
    filter: LogFilterConfig,
}

impl ConsoleLogger {
    pub fn new(filter: LogFilterConfig) -> Self {
        Self { filter }
    }

    fn should_log(&self, target_table: &str) -> bool {
        self.filter.targets.contains(&LogTarget::Console) &&
        self.check_table_filter(target_table)
    }

    fn check_table_filter(&self, target_table: &str) -> bool {
        if let Some(include) = &self.filter.include_tables {
            return include.iter().any(|t| t == target_table);
        }

        if let Some(exclude) = &self.filter.exclude_tables {
            return !exclude.iter().any(|t| t == target_table);
        }

        true
    }
}

#[async_trait]
impl OperationLogger for ConsoleLogger {
    async fn log_operation(
        &self,
        operation: &str,
        target_table: &str,
        record_id: &str,
        data_before: Option<&Value>,
        data_after: Option<&Value>,
        _tx: Option<&DatabaseTransaction>,
    ) -> MijiResult<()> {
        if !self.should_log(target_table) {
            return Ok(());
        }

        info!(
            "Operation: {} on {} (ID: {})\nBefore: {:?}\nAfter: {:?}",
            operation, target_table, record_id, data_before, data_after
        );
        Ok(())
    }
}

/// 文件日志记录器
pub struct FileLogger {
    file_path: PathBuf,
    max_file_size: u64,
    max_files: u32,
    current_file: Mutex<File>,
    current_size: Mutex<u64>,
    filter: LogFilterConfig,
}

impl FileLogger {
    pub async fn new(
        file_path: PathBuf,
        max_file_size: u64,
        max_files: u32,
        filter: LogFilterConfig,
    ) -> MijiResult<Self> {
        let file = Self::create_file(&file_path).await?;
        let metadata = file.metadata().await.map_err(|e| {
            AppError::internal_server_error(format!("Failed to get file metadata: {e}"))
        })?;
        let current_size = metadata.len();

        Ok(Self {
            file_path,
            max_file_size,
            max_files,
            current_file: Mutex::new(file),
            current_size: Mutex::new(current_size),
            filter,
        })
    }

    async fn create_file(path: &PathBuf) -> MijiResult<File> {
        tokio::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
            .await
            .map_err(|e| {
                AppError::internal_server_error(
                    format!("Failed to create log file: {e}")
                )
            })
    }

    async fn rotate_file(&self) -> MijiResult<()> {
        let mut file = self.current_file.lock().await;
        let mut current_size = self.current_size.lock().await;

        // 关闭当前文件
        file.flush().await.map_err(|e| {
            AppError::internal_server_error(
                format!("Failed to flush log file: {e}")
            )
        })?;

        // 轮转日志文件
        let base_name = self.file_path.file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("log");
        let extension = self.file_path.extension()
            .and_then(|s| s.to_str())
            .unwrap_or("log");

        // 重命名旧文件
        for i in (1..self.max_files).rev() {
            let old_name = format!("{base_name}.{i}.{extension}");
            let new_name = format!("{}.{}.{}", base_name, i + 1, extension);

            if tokio::fs::metadata(&old_name).await.is_ok() {
                tokio::fs::rename(&old_name, &new_name).await.map_err(|e| {
                    AppError::internal_server_error(
                        format!("Failed to rotate log file: {e}")
                    )
                })?;
            }
        }

        // 重命名当前文件
        let first_backup = format!("{base_name}.1.{extension}");
        tokio::fs::rename(&self.file_path, &first_backup).await.map_err(|e| {
            AppError::internal_server_error(
                format!("Failed to rename log file: {e}")
            )
        })?;

        // 创建新文件
        *file = Self::create_file(&self.file_path).await?;
        *current_size = 0;

        Ok(())
    }

    fn should_log(&self, target_table: &str) -> bool {
        self.filter.targets.contains(&LogTarget::File) &&
        self.check_table_filter(target_table)
    }

    fn check_table_filter(&self, target_table: &str) -> bool {
        if let Some(include) = &self.filter.include_tables {
            return include.iter().any(|t| t == target_table);
        }

        if let Some(exclude) = &self.filter.exclude_tables {
            return !exclude.iter().any(|t| t == target_table);
        }

        true
    }
}

#[async_trait]
impl OperationLogger for FileLogger {
    async fn log_operation(
        &self,
        operation: &str,
        target_table: &str,
        record_id: &str,
        data_before: Option<&Value>,
        data_after: Option<&Value>,
        _tx: Option<&DatabaseTransaction>,
    ) -> MijiResult<()> {
        if !self.should_log(target_table) {
            return Ok(());
        }

        let log_entry = format!(
            "[{}] {} - {} - {} - Before: {:?} - After: {:?}\n",
            DateUtils::local_rfc3339(),
            operation,
            target_table,
            record_id,
            data_before,
            data_after
        );

        let log_bytes = log_entry.as_bytes();
        let log_size = log_bytes.len() as u64;

        // 检查是否需要轮转
        {
            let mut current_size = self.current_size.lock().await;
            if *current_size + log_size > self.max_file_size * 1024 * 1024 {
                self.rotate_file().await?;
                *current_size = 0;
            }

            *current_size += log_size;
        }

        // 写入日志
        let mut file = self.current_file.lock().await;
        file.write_all(log_bytes).await.map_err(|e| {
            AppError::internal_server_error(
                format!("Failed to write to log file: {e}")
            )
        })?;
        file.flush().await.map_err(|e| {
            AppError::internal_server_error(
                format!("Failed to flush log file: {e}")
            )
        })?;

        Ok(())
    }
}

/// 组合日志记录器
pub struct CompositeLogger {
    loggers: Vec<Arc<dyn OperationLogger>>,
}

impl CompositeLogger {
    pub fn new(loggers: Vec<Arc<dyn OperationLogger>>) -> Self {
        Self { loggers }
    }

    pub fn add_logger(&mut self, logger: Arc<dyn OperationLogger>) {
        self.loggers.push(logger);
    }
}

#[async_trait]
impl OperationLogger for CompositeLogger {
    async fn log_operation(
        &self,
        operation: &str,
        target_table: &str,
        record_id: &str,
        data_before: Option<&Value>,
        data_after: Option<&Value>,
        tx: Option<&DatabaseTransaction>,
    ) -> MijiResult<()> {
        for logger in &self.loggers {
            logger.log_operation(
                operation,
                target_table,
                record_id,
                data_before,
                data_after,
                tx,
            ).await?;
        }
        Ok(())
    }
}
