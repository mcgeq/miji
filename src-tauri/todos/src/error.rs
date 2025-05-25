use common::error::MijiError;
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum TodosError {
    #[snafu(display("Todo not found: {}", id))]
    NotFound { id: String },

    #[snafu(display("Failed to update todo: {}", source))]
    UpdateFailed { source: std::io::Error },
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
