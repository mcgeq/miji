pub mod common;
pub mod env;

pub use common::{AppError, CommonError, ErrorExt};
pub use env::EnvError;

/// 应用程序统一结果类型
pub type MijiResult<T> = Result<T, AppError>;
