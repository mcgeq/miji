use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum TodosError {
    #[snafu(display("Todo not found: {}", id))]
    NotFound { id: u32 },

    #[snafu(display("Failed to update todo: {}", source))]
    UpdateFailed { source: std::io::Error },
}
