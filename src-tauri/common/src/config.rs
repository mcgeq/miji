use tauri::Manager;
use zeroize::Zeroizing;

use crate::{
    business_code::BusinessCode,
    env::env_get_string,
    error::{EnvError, MijiError, MijiResult},
};

pub struct Config {
    pub jwt_secret: Zeroizing<String>,
    pub expired_at: i64,
    pub data_dir: String,
    pub db_url: String,
}

impl Config {
    pub fn load(app_handle: &tauri::AppHandle) -> MijiResult<Self> {
        let jwt_secret = Zeroizing::new(env_get_string("JWT_SECRET").unwrap_or_else(|_| {
            log::warn!("未设置 JWT_SECRET，使用默认值");
            "mcgeqJWTSECRET".to_string()
        }));

        let expired_at = env_get_string("EXPIRED_AT")
            .unwrap_or_else(|_| {
                log::warn!("未设置 EXPIRED_AT，使用默认值");
                "7*24".to_string()
            })
            .parse::<i64>()
            .map_err(|e| {
                MijiError::Env(Box::new(EnvError::EnvParse {
                    code: BusinessCode::EnvVarParseFailure,
                    message: format!("解析 EXPIRED_AT 失败: {e}"),
                }))
            })?;

        let data_dir = app_handle
            .path()
            .home_dir()
            .map_err(|e| {
                MijiError::Env(Box::new(EnvError::HomeDir {
                    source: e,
                    code: BusinessCode::SystemError,
                    message: "无法获取主目录".to_string(),
                }))
            })?
            .join(".tauri-seaorm-template/data")
            .to_str()
            .ok_or_else(|| {
                MijiError::Env(Box::new(EnvError::PathConversion {
                    code: BusinessCode::SystemError,
                    message: "路径转换失败".to_string(),
                }))
            })?
            .to_string();

        let db_url = format!("sqlite://{data_dir}/db.sqlite?mode=rwc");

        Ok(Config {
            jwt_secret,
            expired_at,
            data_dir,
            db_url,
        })
    }

    pub fn load_no() -> MijiResult<Self> {
        let jwt_secret = Zeroizing::new(env_get_string("JWT_SECRET").unwrap_or_else(|_| {
            log::warn!("未设置 JWT_SECRET，使用默认值");
            "mcgeqJWTSECRET".to_string()
        }));

        let expired_at = env_get_string("EXPIRED_AT")
            .unwrap_or_else(|_| {
                log::warn!("未设置 EXPIRED_AT，使用默认值");
                "7*24".to_string()
            })
            .parse::<i64>()
            .map_err(|e| {
                MijiError::Env(Box::new(EnvError::EnvParse {
                    code: BusinessCode::EnvVarParseFailure,
                    message: format!("解析 EXPIRED_AT 失败: {e}"),
                }))
            })?;

        let data_dir = std::env::var("DATA_DIR").unwrap_or_else(|_| "~/.miji/data".to_string());
        let db_url = format!("sqlite://{data_dir}/db.sqlite?mode=rwc");

        Ok(Config {
            jwt_secret,
            expired_at,
            data_dir,
            db_url,
        })
    }
}
