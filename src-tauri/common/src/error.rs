pub mod env;
pub mod common;

pub use common::{AppError, ErrorExt, CommonError};
pub use env::EnvError;

/// 应用程序统一结果类型
pub type MijiResult<T> = Result<T, AppError>;
