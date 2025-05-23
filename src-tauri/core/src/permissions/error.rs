use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum PermissionError {
    #[snafu(display("Insufficient permissions"))]
    InsufficientPermissions,
}
