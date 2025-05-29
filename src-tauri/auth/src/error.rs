use common::{
    business_code::BusinessCode,
    error::{CodeMessage, MijiError},
};
use miji_derive::CodeMessage;
use snafu::Snafu;

#[derive(Debug, Snafu, CodeMessage)]
pub enum UserError {
    #[snafu(display("User not found"))]
    UserNotFound { code: BusinessCode, message: String },

    #[snafu(display("Role not found"))]
    RoleNotFound { code: BusinessCode, message: String },

    #[snafu(display("Permission denied"))]
    PermissionDenied { code: BusinessCode, message: String },

    #[snafu(display("Other error: {message}"))]
    Other { code: BusinessCode, message: String },
}

#[derive(Debug, Snafu, CodeMessage)]
pub enum AuthError {
    #[snafu(display("Invalid credentials"))]
    InvalidCredentials { code: BusinessCode, message: String },

    #[snafu(display("Token expired"))]
    TokenExpired { code: BusinessCode, message: String },

    #[snafu(display("User and Password are failure"))]
    UserAndPasswordFailure { code: BusinessCode, message: String },

    #[snafu(display("Validate failure: {message}"))]
    Validation { code: BusinessCode, message: String },
}

impl From<UserError> for MijiError {
    fn from(value: UserError) -> Self {
        MijiError::User(Box::new(value))
    }
}

impl From<AuthError> for MijiError {
    fn from(value: AuthError) -> Self {
        MijiError::Auth(Box::new(value))
    }
}
