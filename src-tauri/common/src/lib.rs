pub mod argon2id;
pub mod business_code;
pub mod env;
pub mod env_error;
pub mod error;
pub mod jwt;
pub mod response;
pub mod utils;

use serde::Serialize;
use std::sync::Arc;
use tokio::sync::Mutex;
use zeroize::{Zeroize, Zeroizing};

use crate::{env::env_get_string, error::MijiResult};

#[derive(Debug, Clone)]
pub struct AppState {
    pub db: Arc<String>,
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
        let jwt_secret = match env_get_string("JWT_SECRET") {
            Ok(val) => val,
            Err(_) => {
                log::warn!("JWT_SECRET not set in environment, using default value");
                "mcgeqJWTSECRET".to_string()
            }
        };
        Ok(Self {
            jwt_secret: Zeroizing::new(jwt_secret),
        })
    }
}

#[derive(Serialize)]
pub struct TokenResponse {
    pub token: String,
    pub expires_at: usize, // UNIX timestamp
}

#[derive(Serialize)]
pub enum TokenStatus {
    Valid,
    Expired,
    Invalid,
}
