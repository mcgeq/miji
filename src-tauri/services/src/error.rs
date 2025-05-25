use common::error::MijiError;
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum ServicesError {
    #[snafu(display("Service unavailable: {}", name))]
    Unavailable { name: String },

    #[snafu(display("Service error: {}", source))]
    ServiceFailure { source: std::io::Error },
}

impl From<ServicesError> for MijiError {
    fn from(value: ServicesError) -> Self {
        MijiError::Services(Box::new(value))
    }
}
