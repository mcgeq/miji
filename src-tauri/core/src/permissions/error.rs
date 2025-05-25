use common::error::MijiError;
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum PermissionError {
    #[snafu(display("Insufficient permissions"))]
    InsufficientPermissions,
}

impl From<PermissionError> for MijiError {
    fn from(value: PermissionError) -> Self {
        MijiError::Permissions(Box::new(value))
    }
}
