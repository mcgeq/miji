use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum SettingsError {
    #[snafu(display("Failed to load settings: {}", source))]
    LoadFailed { source: std::io::Error },

    #[snafu(display("Invalid setting value: {}", key))]
    InvalidValue { key: String },
}
