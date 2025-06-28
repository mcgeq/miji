use crate::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};
use miji_derive::CodeMessage;
use snafu::{Backtrace, Snafu};
use std::num::ParseIntError;

#[derive(Debug, Snafu, CodeMessage)]
pub enum EnvError {
    #[snafu(display("Environment variable key is empty"))]
    EnvVarEmptyKey {
        code: BusinessCode,
        message: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Environment variable '{message}' is not set"))]
    EnvVarNotPresent {
        code: BusinessCode,
        message: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Environment variable '{message}' is not valid Unicode"))]
    EnvVarNotUnicode {
        code: BusinessCode,
        message: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Failed to parse environment variable '{message}': {source}"))]
    EnvVarParseError {
        code: BusinessCode,
        message: String,
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
