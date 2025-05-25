use common::error::MijiError;
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum NotesError {
    #[snafu(display("Note not found: {}", id))]
    NotFound { id: String },

    #[snafu(display("Failed to save note: {}", source))]
    SaveFailed { source: std::io::Error },
}

impl From<NotesError> for MijiError {
    fn from(value: NotesError) -> Self {
        MijiError::Notes(Box::new(value))
    }
}
