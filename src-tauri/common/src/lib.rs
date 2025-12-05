pub mod argon2id;
pub mod business_code;
pub mod config;
pub mod crud;
pub mod env;
pub mod error;
pub mod jwt;
pub mod log;
pub mod paginations;
pub mod repeat_period_type;
pub mod response;
pub mod state;
pub mod utils;

// 统一通知服务
pub mod services {
    pub mod notification_service;
    
    pub use notification_service::{
        LogRecorder, NotificationAction, NotificationPriority, NotificationRequest,
        NotificationService, NotificationType, PermissionManager, SettingsChecker,
    };
}

pub use business_code::{BusinessCode, ErrorCategory, ErrorModule};
pub use error::{AppError, MijiResult};
pub use response::{ApiResponse, ErrorPayload};
pub use services::{
    LogRecorder, NotificationAction, NotificationPriority, NotificationRequest,
    NotificationService, NotificationType, PermissionManager, SettingsChecker,
};
pub use state::{ApiCredentials, AppState, SetupState, TokenResponse, TokenStatus};
