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
pub mod scheduler_config;
pub mod state;
pub mod utils;

// 服务模块
pub mod services {
    pub mod notification_service;
    pub mod scheduler_config_service;
    
    pub use notification_service::{
        DailyTrend, LogRecorder, NotificationAction, NotificationPriority, NotificationRequest,
        NotificationService, NotificationStatistics, NotificationType, PermissionManager, 
        SettingsChecker, StatisticsService,
    };
    
    pub use scheduler_config_service::{SchedulerConfig, SchedulerConfigService};
}

pub use business_code::{BusinessCode, ErrorCategory, ErrorModule};
pub use error::{AppError, MijiResult};
pub use response::{ApiResponse, ErrorPayload};
pub use scheduler_config::{
    SchedulerConfigCreateRequest, SchedulerConfigResponse, SchedulerConfigUpdateRequest,
};
pub use services::{
    DailyTrend, LogRecorder, NotificationAction, NotificationPriority, NotificationRequest,
    NotificationService, NotificationStatistics, NotificationType, PermissionManager, 
    SchedulerConfig, SchedulerConfigService, SettingsChecker, StatisticsService,
};
pub use state::{ApiCredentials, AppState, SetupState, TokenResponse, TokenStatus};
