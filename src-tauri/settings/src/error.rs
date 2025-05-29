use common::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};
use miji_derive::CodeMessage;

use snafu::Snafu;

#[derive(Debug, Snafu, CodeMessage)]
pub enum SettingsError {
    #[snafu(display("Failed to load settings: {message}"))]
    LoadFailed {
        code: BusinessCode,
        message: String,
        source: std::io::Error,
    },

    #[snafu(display("Invalid setting value: {message}"))]
    InvalidValue { code: BusinessCode, message: String },
}

impl From<SettingsError> for MijiError {
    fn from(value: SettingsError) -> Self {
        MijiError::Settings(Box::new(value))
    }
}
