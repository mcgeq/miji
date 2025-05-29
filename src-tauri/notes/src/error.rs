use common::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};
use miji_derive::CodeMessage;
use snafu::Snafu;

#[derive(Debug, Snafu, CodeMessage)]
pub enum NotesError {
    #[snafu(display("Note not found: {}", id))]
    NotFound {
        code: BusinessCode,
        message: String,
        id: String,
    },

    #[snafu(display("Failed to save note: {}", source))]
    SaveFailed {
        code: BusinessCode,
        message: String,
        source: std::io::Error,
    },
}

impl From<NotesError> for MijiError {
    fn from(value: NotesError) -> Self {
        MijiError::Notes(Box::new(value))
    }
}
