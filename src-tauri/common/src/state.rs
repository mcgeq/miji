use crate::{env::env_get_string, error::MijiResult};
use sea_orm::DatabaseConnection;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::Mutex;
use zeroize::{Zeroize, Zeroizing};

/// 应用程序全局状态
#[derive(Debug, Clone)]
pub struct AppState {
    /// 数据库连接
    pub db: Arc<DatabaseConnection>,

    /// API 凭证
    pub credentials: Arc<Mutex<ApiCredentials>>,
    pub task: Arc<Mutex<SetupState>>,
    // 未来可添加更多全局状态：
    // pub config: Arc<AppConfig>,
    // pub current_user: Arc<Mutex<Option<User>>>,
    // pub cache: Arc<CacheManager>,
}

#[derive(Debug, Clone)]
pub struct SetupState {
    pub frontend_task: bool,
    pub backend_task: bool,
}

/// API 凭证
#[derive(Debug, Zeroize)]
#[zeroize(drop)]
pub struct ApiCredentials {
    /// JWT 密钥
    pub jwt_secret: Zeroizing<String>,

    /// 过期时间（单位：秒）
    pub expired_at: i64,
}

impl ApiCredentials {
    /// 从环境变量加载凭证
    pub fn load_from_env() -> MijiResult<Self> {
        let jwt_secret = match env_get_string("JWT_SECRET") {
            Ok(val) => val,
            Err(_) => {
                log::warn!("JWT_SECRET not set in environment, using default value");
                "mcgeqJWTSECRET".to_string()
            }
        };

        let expired_at = match env_get_string("EXPIRED_AT") {
            Ok(expired) => expired.parse::<i64>().unwrap_or(7 * 24 * 3600),
            Err(_) => 7 * 24 * 3600, // 默认 7 天
        };

        Ok(Self {
            jwt_secret: Zeroizing::new(jwt_secret),
            expired_at,
        })
    }
}

/// 令牌响应
#[derive(Serialize, Deserialize)]
pub struct TokenResponse {
    /// 令牌字符串
    pub token: String,

    /// 过期时间（UNIX 时间戳）
    #[serde(rename = "expiresAt")]
    pub expires_at: usize,
}

/// 令牌状态
#[derive(Serialize)]
pub enum TokenStatus {
    /// 有效
    Valid,

    /// 已过期
    Expired,

    /// 无效
    Invalid,
}
