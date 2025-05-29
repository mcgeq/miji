use common::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};
use miji_derive::CodeMessage;

use snafu::Snafu;

#[derive(Debug, Snafu, CodeMessage)]
pub enum ChecklistsError {
    #[snafu(display("Checklist item not found: {message}"))]
    NotFound { code: BusinessCode, message: String },
}

impl From<ChecklistsError> for MijiError {
    fn from(value: ChecklistsError) -> Self {
        MijiError::CheckLists(Box::new(value))
    }
}
