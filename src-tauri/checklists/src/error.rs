use common::error::MijiError;
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum ChecklistsError {
    #[snafu(display("Checklist item not found: {}", id))]
    NotFound { id: String },
}

impl From<ChecklistsError> for MijiError {
    fn from(value: ChecklistsError) -> Self {
        MijiError::CheckLists(Box::new(value))
    }
}
