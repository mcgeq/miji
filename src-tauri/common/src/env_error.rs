use crate::{business_code::BusinessCode, error::MijiError};
use snafu::{Backtrace, Snafu};
use std::num::ParseIntError;

#[derive(Debug, Snafu)]
pub enum EnvError {
    #[snafu(display("Environment variable key is empty"))]
    EnvVarEmptyKey {
        code: BusinessCode,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Environment variable '{key}' is not set"))]
    EnvVarNotPresent {
        code: BusinessCode,
        key: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Environment variable '{key}' is not valid Unicode"))]
    EnvVarNotUnicode {
        code: BusinessCode,
        key: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Failed to parse environment variable '{key}': {source}"))]
    EnvVarParseError {
        code: BusinessCode,
        key: String,
        #[snafu(source)]
        source: ParseIntError,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },
}

impl From<EnvError> for MijiError {
    fn from(value: EnvError) -> Self {
        MijiError::Env(Box::new(value))
    }
}
