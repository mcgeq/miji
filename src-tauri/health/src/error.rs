use common::error::MijiError;
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum HealthError {
    #[snafu(display("Health check failed: {}", source))]
    CheckFailed { source: std::io::Error },
}

impl From<HealthError> for MijiError {
    fn from(value: HealthError) -> Self {
        MijiError::Health(Box::new(value))
    }
}
