use std::{path::PathBuf, sync::OnceLock};

use snafu::GenerateImplicitData;
use tauri::{AppHandle, Manager};
use zeroize::Zeroizing;

use crate::{
    env::env_get_string,
    error::{AppError, EnvError, MijiResult},
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
                val.parse::<i64>()
                    .map_err(|e| EnvError::EnvVarParseError {
                        var_name: "EXPIRED_AT".to_string(),
                        source: e,
                        backtrace: snafu::Backtrace::generate(),
                    })
                    .map_err(AppError::from)
            })
            .unwrap_or_else(|_| {
                log::warn!("EXPIRED_AT not set, using default (7 days in hours)");
                7 * 24
            });

        let data_dir = get_app_data_dir(app)?;

        std::fs::create_dir_all(&data_dir).map_err(|e| EnvError::FileSystem {
            message: format!("Failed to create directory: {}:{e}", data_dir.display()),
            backtrace: snafu::Backtrace::generate(),
        })?;

        let db_file = data_dir.join("testdb.sqlite");
        let db_url = format!("sqlite:{}?mode=rwc", db_file.display());
        CONFIG
            .set(Config {
                jwt_secret,
                expired_at,
                data_dir,
                db_url,
            })
            .map_err(|_| EnvError::ConfigInit {
                message: "Failed initialized Config".into(),
                backtrace: snafu::Backtrace::generate(),
            })?;
        Ok(())
    }
}

fn get_app_data_dir(app: &AppHandle) -> MijiResult<PathBuf> {
    #[cfg(any(target_os = "ios", target_os = "android"))]
    let result = get_mobile_data_dir(app);

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

    dir.map(|d| d.join("data"))
        .map_err(|e| EnvError::FileSystem {
            message: format!("Failed to create directory: {data_dir}:{e}"),
            backtrace: snafu::Backtrace::generate(),
        })
        .map_err(AppError::from)
}

#[cfg(not(any(target_os = "ios", target_os = "android")))]
fn get_desktop_data_dir(app: &AppHandle) -> MijiResult<PathBuf> {
    app.path()
        .data_dir()
        .map(|home| home.join(".miji/data"))
        .map_err(|e| EnvError::FileSystem {
            message: format!("Failed to create directory: {e}"),
            backtrace: snafu::Backtrace::generate(),
        })
        .map_err(AppError::from)
}
