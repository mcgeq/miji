use std::sync::Arc;
use super::{
    config::{LoggingConfig, LogFilterConfig},
    logger::{OperationLogger, ConsoleLogger, FileLogger, CompositeLogger, NoopLogger},
};
use tracing::error;

/// 创建组合日志记录器
pub async fn create_logger(
    config: &LoggingConfig,
    filter: LogFilterConfig,
) -> Arc<dyn OperationLogger> {
    let mut loggers: Vec<Arc<dyn OperationLogger>> = Vec::new();

    // 控制台日志
    if config.console {
        loggers.push(Arc::new(ConsoleLogger::new(filter.clone())));
    }

    // 文件日志
    if config.file {
        if let Some(file_path) = &config.file_path {
            match FileLogger::new(
                file_path.clone(),
                config.max_file_size,
                config.max_files,
                filter.clone(),
            ).await {
                Ok(file_logger) => {
                    loggers.push(Arc::new(file_logger));
                }
                Err(e) => {
                    // 记录错误但不中断创建
                    error!("Failed to create file logger: {}", e);
                }
            }
        }
    }

    // 注意：数据库日志记录器由服务层提供，所以这里不创建

    if loggers.is_empty() {
        Arc::new(NoopLogger)
    } else {
        Arc::new(CompositeLogger::new(loggers))
    }
}
