use snafu::{Backtrace, GenerateImplicitData};
use sea_orm::DbErr;
use crate::{error::EnvError, BusinessCode};

/// 业务错误特征
pub trait ErrorExt: std::error::Error + Send + Sync + 'static {
    /// 获取业务错误码
    fn business_code(&self) -> BusinessCode;

    /// 获取错误描述
    fn description(&self) -> &'static str {
        self.business_code().description()
    }

    /// 获取附加错误信息
    fn extra_data(&self) -> Option<serde_json::Value> {
        None
    }

    /// 获取回溯信息
    fn backtrace(&self) -> Option<Backtrace> {
        None
    }
}

/// 统一错误类型
#[derive(Debug)]
pub struct AppError(Box<dyn ErrorExt>);

impl AppError {
    /// 创建新错误
    pub fn new<E: ErrorExt + 'static>(error: E) -> Self {
        AppError(Box::new(error))
    }

    /// 获取内部错误
    pub fn inner(&self) -> &dyn ErrorExt {
        self.0.as_ref()
    }

    /// 创建简单的业务错误
    pub fn simple(code: BusinessCode, message: impl Into<String>) -> Self {
        struct SimpleError {
            code: BusinessCode,
            message: String,
        }

        impl std::fmt::Display for SimpleError {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                write!(f, "{}", self.message)
            }
        }

        impl std::error::Error for SimpleError {}

        impl ErrorExt for SimpleError {
            fn business_code(&self) -> BusinessCode {
                self.code
            }
        }

        impl std::fmt::Debug for SimpleError {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                f.debug_struct("SimpleError")
                    .field("code", &self.code.as_str())
                    .field("message", &self.message)
                    .finish()
            }
        }

        AppError::new(SimpleError {
            code,
            message: message.into(),
        })
    }
}

impl<E: ErrorExt + 'static> From<E> for AppError {
    fn from(error: E) -> Self {
        AppError::new(error)
    }
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::error::Error for AppError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        Some(self.0.as_ref())
    }
}

/// 常用错误类型
#[derive(Debug)]
pub enum CommonError {
    /// 数据库错误
    Database {
        source: DbErr,
        backtrace: Backtrace,
        context: Option<serde_json::Value>,
    },

    /// 文件操作错误
    File {
        path: String,
        source: std::io::Error,
        backtrace: Backtrace,
    },

    /// 配置错误
    Config {
        source: Box<dyn std::error::Error + Send + Sync>,
        backtrace: Backtrace,
    },

    /// 环境变量错误
    Env {
        source: EnvError,
        backtrace: Backtrace,
    },
}

impl std::fmt::Display for CommonError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Database { source, .. } => write!(f, "Database error: {}", source),
            Self::File { path, source, .. } => write!(f, "File error at {}: {}", path, source),
            Self::Config { source, .. } => write!(f, "Configuration error: {}", source),
            Self::Env { source, .. } => write!(f, "Environment error: {}", source),
        }
    }
}

impl std::error::Error for CommonError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Database { source, .. } => Some(source),
            Self::File { source, .. } => Some(source),
            Self::Config { source, .. } => Some(source.as_ref()),
            Self::Env { source, .. } => Some(source),
        }
    }
}

impl ErrorExt for CommonError {
    fn business_code(&self) -> BusinessCode {
        match self {
            Self::Database { .. } => BusinessCode::DatabaseError,
            Self::File { .. } => BusinessCode::FileError,
            Self::Config { .. } => BusinessCode::ConfigError,
            Self::Env { source, .. } => source.business_code(),
        }
    }

    fn extra_data(&self) -> Option<serde_json::Value> {
        match self {
            Self::Database { context, .. } => context.clone(),
            Self::File { path, .. } => Some(serde_json::json!({ "path": path })),
            Self::Config { .. } => None,
            Self::Env { source, .. } => source.extra_data(),
        }
    }

    fn backtrace(&self) -> Option<Backtrace> {
        match self {
            Self::Database { backtrace, .. } => Some(backtrace.clone()),
            Self::File { backtrace, .. } => Some(backtrace.clone()),
            Self::Config { backtrace, .. } => Some(backtrace.clone()),
            Self::Env { backtrace, .. } => Some(backtrace.clone()),
        }
    }
}

// 实现 From 转换
impl From<DbErr> for AppError {
    fn from(error: DbErr) -> Self {
        CommonError::Database {
            source: error,
            backtrace: snafu::Backtrace::generate(),
            context: None,
        }
        .into()
    }
}

impl From<std::io::Error> for AppError {
    fn from(error: std::io::Error) -> Self {
        CommonError::File {
            path: "".to_string(), // 实际使用中应替换为实际路径
            source: error,
            backtrace: snafu::Backtrace::generate()
        }
        .into()
    }
}
