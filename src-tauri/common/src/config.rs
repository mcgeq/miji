use std::{path::PathBuf, sync::OnceLock};

use tauri::{AppHandle, Manager};
use zeroize::Zeroizing;

use crate::{
    business_code::BusinessCode,
    env::env_get_string,
    error::{EnvError, MijiError, MijiResult},
};

static CONFIG: OnceLock<Config> = OnceLock::new();

pub struct Config {
    pub jwt_secret: Zeroizing<String>,
    pub expired_at: i64,
    pub data_dir: PathBuf,
    pub db_url: String,
}

impl Config {
    pub fn get() -> &'static Config {
        CONFIG.get().expect("Config not initialized")
    }

    pub fn init(app: &AppHandle) -> MijiResult<()> {
        let jwt_secret = Zeroizing::new(env_get_string("JWT_SECRET").unwrap_or_else(|_| {
            log::warn!("JWT_SECRET not set, using default");
            "mcgeqJWTSECRET".to_string()
        }));

        let expired_at = env_get_string("EXPIRED_AT")
            .and_then(|val| {
                val.parse::<i64>().map_err(|e| {
                    MijiError::Env(Box::new(EnvError::EnvParse {
                        code: BusinessCode::EnvVarParseFailure,
                        message: format!("Failed to parse EXPIRED_AT: {e}"),
                    }))
                })
            })
            .unwrap_or_else(|_| {
                log::warn!("EXPIRED_AT not set, using default (7 days in hours)");
                7 * 24
            });
        let data_dir = get_app_data_dir(app)?;

        std::fs::create_dir_all(&data_dir).map_err(|_| {
            MijiError::Env(Box::new(EnvError::PathConversion {
                code: BusinessCode::SystemError,
                message: "Failed to create data directory".into(),
            }))
        })?;

        let db_file = data_dir.join("db.sqlite");
        let db_url = format!("sqlite:{}?mode=rwc", db_file.display());
        CONFIG
            .set(Config {
                jwt_secret,
                expired_at,
                data_dir,
                db_url,
            })
            .map_err(|_| {
                MijiError::Env(Box::new(EnvError::EnvParse {
                    code: BusinessCode::SystemError,
                    message: "Failed initialized Config".into(),
                }))
            })
    }
}

fn get_app_data_dir(app: &AppHandle) -> MijiResult<PathBuf> {
    #[cfg(not(any(target_os = "ios", target_os = "android")))]
    {
        if let Ok(dir) = env_get_string("DATA_DIR") {
            return Ok(PathBuf::from(dir));
        }
    }

    #[cfg(any(target_os = "ios", target_os = "android"))]
    let result = get_mobile_data_dir(app);
    #[cfg(not(any(target_os = "ios", target_os = "android")))]
    let result = get_desktop_data_dir(app);

    result
}

#[cfg(any(target_os = "ios", target_os = "android"))]
fn get_mobile_data_dir(app: &AppHandle) -> MijiResult<PathBuf> {
    // iOS
    #[cfg(target_os = "ios")]
    let dir = app.path().document_dir();

    #[cfg(target_os = "android")]
    let dir = app.path().data_dir();

    dir.map(|d| d.join("data")).map_err(|e| {
        MijiError::Env(EnvError::HomeDir {
            source: e,
            code: BusinessCode::SystemError,
            message: "Failed to get mobile data director".into(),
        })
    })
}

#[cfg(not(any(target_os = "ios", target_os = "android")))]
fn get_desktop_data_dir(app: &AppHandle) -> MijiResult<PathBuf> {
    app.path()
        .data_dir()
        .map(|home| home.join(".miji/data"))
        .map_err(|e| {
            MijiError::Env(Box::new(EnvError::HomeDir {
                source: e,
                code: BusinessCode::SystemError,
                message: "Failed to get hoe directory".into(),
            }))
        })
}
