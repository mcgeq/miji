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

use env::env_get_string;
use error::MijiResult;
use sea_orm::DatabaseConnection;
use std::sync::Arc;
use tokio::sync::Mutex;
use zeroize::{Zeroize, Zeroizing};

#[derive(Debug, Clone)]
pub struct AppState {
    pub db: Arc<DatabaseConnection>,
    pub credentials: Arc<Mutex<ApiCredentials>>,
    // 未来还可加更多全局状态，如：
    // pub config: Arc<AppConfig>,
    // pub current_user: Arc<Mutex<Option<User>>>,
}

#[derive(Debug, Zeroize)]
#[zeroize(drop)]
pub struct ApiCredentials {
    pub jwt_secret: Zeroizing<String>,
}

impl ApiCredentials {
    pub fn load_from_env() -> MijiResult<Self> {
        let jwt_secret = env_get_string("JWT_SECRET")?;
        let jwt_secret = Zeroizing::new(jwt_secret);
        Ok(Self { jwt_secret })
    }
}
