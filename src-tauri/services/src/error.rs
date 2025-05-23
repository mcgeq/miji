use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum ServicesError {
    #[snafu(display("Service unavailable: {}", name))]
    Unavailable { name: String },

    #[snafu(display("Service error: {}", source))]
    ServiceFailure { source: std::io::Error },
}
