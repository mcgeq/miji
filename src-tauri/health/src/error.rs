use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum HealthError {
    #[snafu(display("Health check failed: {}", source))]
    CheckFailed { source: std::io::Error },
}
