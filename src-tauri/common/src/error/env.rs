use crate::{BusinessCode, error::ErrorExt};
use snafu::{Backtrace, Snafu};
use std::num::ParseIntError;

/// 环境变量相关错误
#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum EnvError {
    #[snafu(display("Environment variable key is empty"))]
    EnvVarEmptyKey {
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Environment variable '{}' is not set", var_name))]
    EnvVarNotPresent {
        var_name: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Environment variable '{}' is not valid Unicode", var_name))]
    EnvVarNotUnicode {
        var_name: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Failed to parse environment variable '{}': {}", var_name, source))]
    EnvVarParseError {
        var_name: String,
        source: ParseIntError,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("File system error: {}", message))]
    FileSystem {
        message: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },
    #[snafu(display("Configuration initialization failed: {}", message))]
    ConfigInit {
        message: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },
}

impl ErrorExt for EnvError {
    fn business_code(&self) -> BusinessCode {
        match self {
            Self::EnvVarEmptyKey { .. } => BusinessCode::EnvVarEmptyKey,
            Self::EnvVarNotPresent { .. } => BusinessCode::EnvVarNotPresent,
            Self::EnvVarNotUnicode { .. } => BusinessCode::EnvVarNotUnicode,
            Self::EnvVarParseError { .. } => BusinessCode::EnvVarParseFailure,
            Self::FileSystem { .. } => BusinessCode::SystemError,
            Self::ConfigInit { .. } => BusinessCode::SystemError,
        }
    }

    fn description(&self) -> &'static str {
        self.business_code().description()
    }

    fn extra_data(&self) -> Option<serde_json::Value> {
        match self {
            Self::EnvVarEmptyKey { .. } => None,
            Self::EnvVarNotPresent { var_name, .. } => {
                Some(serde_json::json!({ "var_name": var_name }))
            }
            Self::EnvVarNotUnicode { var_name, .. } => {
                Some(serde_json::json!({ "var_name": var_name }))
            }
            Self::EnvVarParseError {
                var_name, source, ..
            } => Some(serde_json::json!({
                "var_name": var_name,
                "error": source.to_string()
            })),
            Self::FileSystem { message, .. } => Some(serde_json::json!({ "message": message })),
            Self::ConfigInit { message, .. } => Some(serde_json::json!({ "message": message })),
        }
    }

    fn backtrace(&self) -> Option<Backtrace> {
        match self {
            Self::EnvVarEmptyKey { backtrace, .. } => Some(backtrace.clone()),
            Self::EnvVarNotPresent { backtrace, .. } => Some(backtrace.clone()),
            Self::EnvVarNotUnicode { backtrace, .. } => Some(backtrace.clone()),
            Self::EnvVarParseError { backtrace, .. } => Some(backtrace.clone()),
            Self::FileSystem { backtrace, .. } => Some(backtrace.clone()),
            Self::ConfigInit { backtrace, .. } => Some(backtrace.clone()),
        }
    }
}
