// mod 导出
pub mod config;
pub mod formatter;
pub mod manager;

// 导出常量
pub const LOG_TARGET_TRACING: &str = "miji::logging";
pub const LOG_TARGET_PERF: &str = "miji::performance";
pub const LOG_TARGET_AUDIT: &str = "miji::audit";
pub const LOG_TARGET_OPERATION: &str = "miji::operation";

// 导出宏模块（使宏可以被外部使用）
#[macro_use]
pub mod macros {
    /// 性能日志宏
    #[macro_export]
    macro_rules! perf_log {
        ($operation:expr, $($arg:tt)*) => {
            tracing::info!(
                target: "miji::performance",
                operation = $operation,
                $($arg)*
            );
        };
    }

    /// 业务操作日志宏
    #[macro_export]
    macro_rules! operation_log {
        ($action:expr, $entity:expr, $entity_id:expr, $($arg:tt)*) => {
            tracing::info!(
                target: "miji::operation",
                action = $action,
                entity = $entity,
                entity_id = $entity_id,
                $($arg)*
            );
        };
    }

    /// 审计日志宏
    #[macro_export]
    macro_rules! audit_log {
        ($user_id:expr, $action:expr, $resource:expr, $($arg:tt)*) => {
            tracing::info!(
                target: "miji::audit",
                user_id = $user_id,
                action = $action,
                resource = $resource,
                timestamp = chrono::Utc::now().to_rfc3339(),
                $($arg)*
            );
        };
    }

    /// 性能监控宏（带自动计时）
    #[macro_export]
    macro_rules! perf_measure {
        ($operation:expr, $body:block) => {{
            let start = std::time::Instant::now();
            let result = $body;
            let duration = start.elapsed();
            
            perf_log!(
                $operation,
                duration_ms = duration.as_millis(),
                duration_ns = duration.as_nanos()
            );
            
            result
        }};
    }

    /// 错误日志宏（带上下文）
    #[macro_export]
    macro_rules! error_with_context {
        ($error:expr, $($arg:tt)*) => {
            tracing::error!(
                error = %$error,
                $($arg)*
            );
        };
    }

    /// 调试日志宏（仅在调试模式启用）
    #[macro_export]
    macro_rules! debug_log {
        ($($arg:tt)*) => {
            #[cfg(debug_assertions)]
            tracing::debug!($($arg)*);
        };
    }
}
