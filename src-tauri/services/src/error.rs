use common::{business_code::BusinessCode, error::MijiError};
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum ServicesError {
    #[snafu(display("Service unavailable: {message}"))]
    Unavailable { code: BusinessCode, message: String },

    #[snafu(display("Service error: {message}"))]
    ServiceFailure {
        code: BusinessCode,
        message: String,
        source: std::io::Error,
    },
}

impl From<ServicesError> for MijiError {
    fn from(value: ServicesError) -> Self {
        MijiError::Services(Box::new(value))
    }
}
