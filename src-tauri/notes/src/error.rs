use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum NotesError {
    #[snafu(display("Note not found: {}", id))]
    NotFound { id: u32 },

    #[snafu(display("Failed to save note: {}", source))]
    SaveFailed { source: std::io::Error },
}
