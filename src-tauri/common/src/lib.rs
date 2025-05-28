pub mod argon2id;
pub mod business_code;
pub mod db;
pub mod db_error;
pub mod entity;
pub mod env;
pub mod env_error;
pub mod error;
pub mod sql_error;
pub mod utils;

use sea_orm::DatabaseConnection;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct AppState {
    pub db: Arc<DatabaseConnection>,
    // 未来还可加更多全局状态，如：
    // pub config: Arc<AppConfig>,
    // pub current_user: Arc<Mutex<Option<User>>>,
}

pub struct ApiCredentials {
    api_secret: String,
}
