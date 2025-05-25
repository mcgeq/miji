use common::error::MijiError;
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum SettingsError {
    #[snafu(display("Failed to load settings: {}", source))]
    LoadFailed { source: std::io::Error },

    #[snafu(display("Invalid setting value: {}", key))]
    InvalidValue { key: String },
}

impl From<SettingsError> for MijiError {
    fn from(value: SettingsError) -> Self {
        MijiError::Settings(Box::new(value))
    }
}
