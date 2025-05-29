use common::{business_code::BusinessCode, error::MijiError};
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum HealthError {
    #[snafu(display("Health check failed: {}", source))]
    CheckFailed {
        code: BusinessCode,
        message: String,
        source: std::io::Error,
    },
}

impl From<HealthError> for MijiError {
    fn from(value: HealthError) -> Self {
        MijiError::Health(Box::new(value))
    }
}
