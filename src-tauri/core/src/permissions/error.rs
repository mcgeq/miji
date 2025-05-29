use common::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};
use miji_derive::CodeMessage;
use snafu::Snafu;

#[derive(Debug, Snafu, CodeMessage)]
pub enum PermissionError {
    #[snafu(display("Insufficient permissions"))]
    InsufficientPermissions { code: BusinessCode, message: String },
}

impl From<PermissionError> for MijiError {
    fn from(value: PermissionError) -> Self {
        MijiError::Permissions(Box::new(value))
    }
}
