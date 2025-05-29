use common::{business_code::BusinessCode, error::MijiError};
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum TodosError {
    #[snafu(display("Todo not found: {message}"))]
    NotFound { code: BusinessCode, message: String },

    #[snafu(display("Failed to update todo: {message}"))]
    UpdateFailed { code: BusinessCode, message: String },
}

impl From<TodosError> for MijiError {
    fn from(value: TodosError) -> Self {
        MijiError::Todos(Box::new(value))
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_todos_error_display() {}
}
