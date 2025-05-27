use common::error::MijiError;
use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum UserError {
    #[snafu(display("User not found"))]
    UserNotFound,

    #[snafu(display("Role not found"))]
    RoleNotFound,

    #[snafu(display("Permission denied"))]
    PermissionDenied,

    #[snafu(display("Other error: {}", message))]
    Other { message: String },
}

#[derive(Debug, Snafu)]
pub enum AuthError {
    #[snafu(display("Invalid credentials"))]
    InvalidCredentials,

    #[snafu(display("Token expired"))]
    TokenExpired,

    #[snafu(display("User and Password are failure"))]
    UserAndPasswordFailure,

    #[snafu(display("Validate failure: {details}"))]
    Validation { details: String },
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
