pub mod utils;

use std::sync::Arc;
use tokio::sync::Mutex;
use zeroize::{Zeroize, Zeroizing};

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
