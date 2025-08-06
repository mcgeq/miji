use serde::{Deserialize, Serialize};

/// 错误分类枚举
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ErrorCategory {
    /// 成功
    Success,
    /// 命令错误
    Command,
    /// 验证错误
    Validation,
    /// 数据库错误
    Database,
    /// 文件错误
    File,
    /// 配置错误
    Config,
    /// 网络错误
    Network,
    /// 认证错误
    Auth,
    /// 资源错误
    Resource,
    /// 财务错误
    Money,
    /// 待办错误
    Todo,
    /// 提醒错误
    Reminder,
    /// 健康错误
    Health,
    /// 月经错误
    Menstrual,
    /// 环境错误
    Env,
    /// 系统错误
    System,
}

impl ErrorCategory {
    /// 获取分类编码 (2位数字)
    pub fn code(&self) -> &'static str {
        match self {
            Self::Success => "00",
            Self::Command => "01",
            Self::Validation => "02",
            Self::Database => "03",
            Self::File => "04",
            Self::Config => "05",
            Self::Network => "06",
            Self::Auth => "07",
            Self::Resource => "08",
            Self::Money => "09",
            Self::Todo => "10",
            Self::Reminder => "11",
            Self::Health => "12",
            Self::Menstrual => "13",
            Self::Env => "14",
            Self::System => "99",
        }
    }

    /// 获取分类名称
    pub fn name(&self) -> &'static str {
        match self {
            Self::Success => "Success",
            Self::Command => "Command",
            Self::Validation => "Validation",
            Self::Database => "Database",
            Self::File => "File",
            Self::Config => "Config",
            Self::Network => "Network",
            Self::Auth => "Auth",
            Self::Resource => "Resource",
            Self::Money => "Money",
            Self::Todo => "Todo",
            Self::Reminder => "Reminder",
            Self::Health => "Health",
            Self::Menstrual => "Menstrual",
            Self::Env => "Env",
            Self::System => "System",
        }
    }

    /// 转换为小写字符串（用于序列化）
    pub fn as_str(&self) -> String {
        self.name().to_lowercase()
    }
}

impl From<ErrorCategory> for String {
    fn from(category: ErrorCategory) -> Self {
        category.as_str()
    }
}

/// 错误模块枚举
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ErrorModule {
    /// 核心模块
    Core,
    /// 财务模块
    Money,
    /// 待办模块
    Todo,
    /// 提醒模块
    TodoReminder,
    /// 健康模块
    Health,
    /// 月经模块
    Menstrual,
    /// 环境模块
    Env,
    /// 系统模块
    System,
    /// 认证模块
    Auth,
}

impl ErrorModule {
    /// 获取模块编码 (2位数字)
    pub fn code(&self) -> &'static str {
        match self {
            Self::Core => "00",
            Self::Money => "01",
            Self::Todo => "02",
            Self::TodoReminder => "03",
            Self::Health => "04",
            Self::Menstrual => "05",
            Self::Env => "06",
            Self::System => "99",
            Self::Auth => "07",
        }
    }

    /// 获取模块名称
    pub fn name(&self) -> &'static str {
        match self {
            Self::Core => "Core",
            Self::Money => "Money",
            Self::Todo => "Todo",
            Self::TodoReminder => "TodoReminder",
            Self::Health => "Health",
            Self::Menstrual => "Menstrual",
            Self::Env => "Env",
            Self::System => "System",
            Self::Auth => "Auth",
        }
    }

    /// 转换为小写字符串（用于序列化）
    pub fn as_str(&self) -> String {
        match self {
            Self::TodoReminder => "todo_reminder".to_string(),
            // 其他模块使用动态生成
            _ => self.name().to_lowercase(),
        }
    }
}

impl From<ErrorModule> for String {
    fn from(module: ErrorModule) -> Self {
        module.as_str()
    }
}

/// 统一业务错误码
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BusinessCode {
    // ===== 基础错误码 (0-999) =====
    /// 成功
    Success,
    /// 命令执行失败
    CommandFailed,
    /// 验证错误
    ValidationError,
    /// 数据库错误
    DatabaseError,
    /// 文件操作错误
    FileError,
    /// 配置错误
    ConfigError,
    /// 网络错误
    NetworkError,
    /// 无效参数
    InvalidParameter,
    /// 未授权
    Unauthorized,
    /// 认证失败
    AuthenticationFailed,
    /// 禁止访问
    Forbidden,
    /// 未找到
    NotFound,
    /// 会话过期
    SessionExpired,
    /// 令牌无效
    TokenInvalid,
    /// 权限不足
    InsufficientPermissions,
    /// 刷新令牌过期
    RefreshTokenExpired,
    /// 无效凭证
    InvalidCredentials,
    /// 账户已锁定
    AccountLocked,
    /// 账户未验证
    AccountNotVerified,
    /// 需要双因素认证
    TwoFactorRequired,
    /// 双因素认证失败
    TwoFactorFailed,
    /// 令牌生成失败
    TokenGenerationFailed,
    /// 令牌过期
    TokenExpired,
    /// 序列化错误
    SerializationError,
    /// 反序列化错误
    DeserializationError,
    /// 密码哈希错误
    PasswordHashError,
    /// 密码验证错误
    PasswordVerifyError,
    /// 密码格式错误
    PasswordFormatError,

    // ===== 财务模块错误码 (1000-1999) =====
    /// 余额不足
    MoneyInsufficientFunds,
    /// 支付失败
    MoneyPaymentFailed,
    /// 交易未找到
    MoneyTransactionNotFound,
    /// 无效的货币类型
    MoneyInvalidCurrency,
    /// 无效的金额
    MoneyInvalidAmount,
    /// 账户已冻结
    MoneyAccountFrozen,
    /// 转账限制
    MoneyTransferLimitExceeded,
    /// 外部支付服务错误
    MoneyExternalPaymentError,
    /// 无效的账号
    MoneyInvalidAccountNumber,
    /// 货币转换失败
    MoneyCurrencyConversionFailed,
    /// 交易被拒绝
    MoneyTransactionDeclined,
    /// 欺诈检测警报
    MoneyFraudDetectionAlert,

    // ===== 待办模块错误码 (2000-2999) =====
    /// 待办未找到
    TodoNotFound,
    /// 待办已完成
    TodoCompleted,
    /// 待办已存在
    TodoAlreadyExists,
    /// 待办外部服务错误
    TodoExternalService,

    // ===== 待办提醒类错误码 (2100-2199) =====
    /// 提醒时间无效
    TodoReminderInvalidTime,
    /// 提醒重复设置无效
    TodoReminderInvalidRecurrence,
    /// 提醒未找到
    TodoReminderNotFound,
    /// 提醒已过期
    TodoReminderExpired,
    /// 提醒服务不可用
    TodoReminderServiceUnavailable,

    // ===== 环境变量错误码 (3000-3999) =====
    /// 环境变量键为空
    EnvVarEmptyKey,
    /// 环境变量未设置
    EnvVarNotPresent,
    /// 环境变量非 Unicode
    EnvVarNotUnicode,
    /// 环境变量解析失败
    EnvVarParseFailure,

    // ===== 健康模块错误码 (4000-4999) =====
    /// 健康数据未找到
    HealthDataNotFound,
    /// 健康数据无效
    HealthDataInvalid,
    /// 健康目标未设置
    HealthGoalNotSet,
    /// 健康目标已达成
    HealthGoalAchieved,
    /// 健康目标进度无效
    HealthGoalProgressInvalid,
    /// 健康服务连接失败
    HealthServiceConnectionFailed,

    // ===== 月经经期类错误码 (4100-4199) =====
    /// 经期记录未找到
    MenstrualCycleNotFound,
    /// 经期开始日期无效
    MenstrualCycleStartDateInvalid,
    /// 经期周期长度无效
    MenstrualCycleLengthInvalid,
    /// 经期持续时间无效
    MenstrualDurationInvalid,
    /// 经期预测失败
    MenstrualPredictionFailed,
    /// 经期症状记录无效
    MenstrualSymptomInvalid,
    /// 经期提醒设置失败
    MenstrualReminderSetupFailed,
    /// 经期数据同步失败
    MenstrualDataSyncFailed,

    // ===== 其他错误码 (9000-9999) =====
    /// 系统错误
    SystemError,
}

impl BusinessCode {
    /// 获取错误码字符串（6 位格式）
    pub fn as_str(&self) -> String {
        format!(
            "{}{}{:02}",
            self.module().code(),
            self.category().code(),
            self.order()
        )
    }

    /// 获取错误在分类中的序号
    pub fn order(&self) -> u8 {
        match self {
            // 基础错误码
            Self::Success => 0,
            Self::CommandFailed => 1,
            Self::ValidationError => 2,
            Self::DatabaseError => 3,
            Self::FileError => 4,
            Self::ConfigError => 5,
            Self::NetworkError => 6,
            Self::Unauthorized => 7,
            Self::Forbidden => 8,
            Self::NotFound => 9,
            Self::InvalidParameter => 10,
            Self::AuthenticationFailed => 11,
            Self::SessionExpired => 12,
            Self::TokenInvalid => 13,
            Self::InsufficientPermissions => 14,
            Self::RefreshTokenExpired => 15,
            Self::InvalidCredentials => 16,
            Self::AccountLocked => 17,
            Self::AccountNotVerified => 18,
            Self::TwoFactorRequired => 19,
            Self::TwoFactorFailed => 20,
            Self::TokenGenerationFailed => 21,
            Self::TokenExpired => 22,
            Self::SerializationError => 23,
            Self::DeserializationError => 24,
            Self::PasswordHashError => 25,
            Self::PasswordVerifyError => 26,
            Self::PasswordFormatError => 27,

            // 财务模块错误码
            Self::MoneyInsufficientFunds => 1,
            Self::MoneyPaymentFailed => 2,
            Self::MoneyTransactionNotFound => 3,
            Self::MoneyInvalidCurrency => 4,
            Self::MoneyInvalidAmount => 5,
            Self::MoneyAccountFrozen => 6,
            Self::MoneyTransferLimitExceeded => 7,
            Self::MoneyExternalPaymentError => 8,
            Self::MoneyInvalidAccountNumber => 9,
            Self::MoneyCurrencyConversionFailed => 10,
            Self::MoneyTransactionDeclined => 11,
            Self::MoneyFraudDetectionAlert => 12,

            // 待办模块错误码
            Self::TodoNotFound => 1,
            Self::TodoCompleted => 2,
            Self::TodoAlreadyExists => 3,
            Self::TodoExternalService => 4,

            // 待办提醒类错误码
            Self::TodoReminderInvalidTime => 1,
            Self::TodoReminderInvalidRecurrence => 2,
            Self::TodoReminderNotFound => 3,
            Self::TodoReminderExpired => 4,
            Self::TodoReminderServiceUnavailable => 5,

            // 环境变量错误码
            Self::EnvVarEmptyKey => 1,
            Self::EnvVarNotPresent => 2,
            Self::EnvVarNotUnicode => 3,
            Self::EnvVarParseFailure => 4,

            // 健康模块错误码
            Self::HealthDataNotFound => 1,
            Self::HealthDataInvalid => 2,
            Self::HealthGoalNotSet => 3,
            Self::HealthGoalAchieved => 4,
            Self::HealthGoalProgressInvalid => 5,
            Self::HealthServiceConnectionFailed => 6,

            // 月经经期类错误码
            Self::MenstrualCycleNotFound => 1,
            Self::MenstrualCycleStartDateInvalid => 2,
            Self::MenstrualCycleLengthInvalid => 3,
            Self::MenstrualDurationInvalid => 4,
            Self::MenstrualPredictionFailed => 5,
            Self::MenstrualSymptomInvalid => 6,
            Self::MenstrualReminderSetupFailed => 7,
            Self::MenstrualDataSyncFailed => 8,

            // 其他错误码
            Self::SystemError => 99,
        }
    }

    /// 获取错误描述
    pub fn description(&self) -> &'static str {
        match self {
            // 基础错误描述
            Self::Success => "Success",
            Self::CommandFailed => "Command execution failed",
            Self::ValidationError => "Validation error",
            Self::DatabaseError => "Database operation failed",
            Self::FileError => "File operation failed",
            Self::ConfigError => "Configuration error",
            Self::NetworkError => "Network error",
            Self::Unauthorized => "Unauthorized access",
            Self::Forbidden => "Forbidden access",
            Self::NotFound => "Resource not found",
            Self::InvalidParameter => "Invalid parameter",
            Self::AuthenticationFailed => "Authentication failed",
            Self::SessionExpired => "Session expired",
            Self::TokenInvalid => "Invalid token",
            Self::InsufficientPermissions => "Insufficient permissions",
            Self::RefreshTokenExpired => "Refresh token expired",
            Self::InvalidCredentials => "Invalid credentials",
            Self::AccountLocked => "Account locked",
            Self::AccountNotVerified => "Account not verified",
            Self::TwoFactorRequired => "Two-factor authentication required",
            Self::TwoFactorFailed => "Two-factor authentication failed",
            Self::TokenGenerationFailed => "Token generation failed",
            Self::TokenExpired => "Token expired",
            Self::SerializationError => "Serialization error",
            Self::DeserializationError => "Deserialization error",
            Self::PasswordHashError => "Password hashing failed",
            Self::PasswordVerifyError => "Password verification failed",
            Self::PasswordFormatError => "Invalid password format",

            // 财务模块错误描述
            Self::MoneyInsufficientFunds => "Insufficient funds",
            Self::MoneyPaymentFailed => "Payment failed",
            Self::MoneyTransactionNotFound => "Transaction not found",
            Self::MoneyInvalidCurrency => "Invalid currency",
            Self::MoneyInvalidAmount => "Invalid amount",
            Self::MoneyAccountFrozen => "Account frozen",
            Self::MoneyTransferLimitExceeded => "Transfer limit exceeded",
            Self::MoneyExternalPaymentError => "External payment service error",
            Self::MoneyInvalidAccountNumber => "Invalid account number",
            Self::MoneyCurrencyConversionFailed => "Currency conversion failed",
            Self::MoneyTransactionDeclined => "Transaction declined",
            Self::MoneyFraudDetectionAlert => "Fraud detection alert",

            // 待办模块错误描述
            Self::TodoNotFound => "Todo not found",
            Self::TodoCompleted => "Todo already completed",
            Self::TodoAlreadyExists => "Todo already exists",
            Self::TodoExternalService => "External service error",

            // 待办提醒类错误描述
            Self::TodoReminderInvalidTime => "Reminder time is invalid",
            Self::TodoReminderInvalidRecurrence => "Reminder recurrence setting is invalid",
            Self::TodoReminderNotFound => "Reminder not found",
            Self::TodoReminderExpired => "Reminder has expired",
            Self::TodoReminderServiceUnavailable => "Reminder service unavailable",

            // 健康模块错误描述
            Self::HealthDataNotFound => "Health data not found",
            Self::HealthDataInvalid => "Invalid health data",
            Self::HealthGoalNotSet => "Health goal not set",
            Self::HealthGoalAchieved => "Health goal already achieved",
            Self::HealthGoalProgressInvalid => "Invalid health goal progress",
            Self::HealthServiceConnectionFailed => "Health service connection failed",

            // 月经经期类错误描述
            Self::MenstrualCycleNotFound => "Menstrual cycle record not found",
            Self::MenstrualCycleStartDateInvalid => "Invalid menstrual cycle start date",
            Self::MenstrualCycleLengthInvalid => "Invalid menstrual cycle length",
            Self::MenstrualDurationInvalid => "Invalid menstrual duration",
            Self::MenstrualPredictionFailed => "Menstrual cycle prediction failed",
            Self::MenstrualSymptomInvalid => "Invalid menstrual symptom record",
            Self::MenstrualReminderSetupFailed => "Menstrual reminder setup failed",
            Self::MenstrualDataSyncFailed => "Menstrual data synchronization failed",

            // 环境变量错误描述
            Self::EnvVarEmptyKey => "Environment variable key is empty",
            Self::EnvVarNotPresent => "Environment variable not set",
            Self::EnvVarNotUnicode => "Environment variable not valid Unicode",
            Self::EnvVarParseFailure => "Environment variable parsing failed",

            // 其他错误描述
            Self::SystemError => "System error",
        }
    }

    /// 获取错误分类
    pub fn category(&self) -> ErrorCategory {
        match self {
            // 基础错误分类
            Self::Success => ErrorCategory::Success,
            Self::CommandFailed => ErrorCategory::Command,
            Self::ValidationError => ErrorCategory::Validation,
            Self::DatabaseError => ErrorCategory::Database,
            Self::FileError => ErrorCategory::File,
            Self::ConfigError => ErrorCategory::Config,
            Self::NetworkError => ErrorCategory::Network,
            Self::Unauthorized => ErrorCategory::Auth,
            Self::Forbidden => ErrorCategory::Auth,
            Self::NotFound => ErrorCategory::Resource,
            Self::InvalidParameter => ErrorCategory::Validation,
            Self::AuthenticationFailed => ErrorCategory::Auth,
            Self::SessionExpired => ErrorCategory::Auth,
            Self::TokenInvalid => ErrorCategory::Auth,
            Self::InsufficientPermissions => ErrorCategory::Auth,
            Self::RefreshTokenExpired => ErrorCategory::Auth,
            Self::InvalidCredentials => ErrorCategory::Auth,
            Self::AccountLocked => ErrorCategory::Auth,
            Self::AccountNotVerified => ErrorCategory::Auth,
            Self::TwoFactorRequired => ErrorCategory::Auth,
            Self::TwoFactorFailed => ErrorCategory::Auth,
            Self::TokenExpired => ErrorCategory::Auth,
            Self::TokenGenerationFailed => ErrorCategory::Auth,
            Self::PasswordHashError => ErrorCategory::Auth,
            Self::PasswordVerifyError => ErrorCategory::Auth,
            Self::PasswordFormatError => ErrorCategory::Auth,

            // 财务模块错误分类
            Self::MoneyInsufficientFunds => ErrorCategory::Money,
            Self::MoneyPaymentFailed => ErrorCategory::Money,
            Self::MoneyTransactionNotFound => ErrorCategory::Money,
            Self::MoneyInvalidCurrency => ErrorCategory::Money,
            Self::MoneyInvalidAmount => ErrorCategory::Money,
            Self::MoneyAccountFrozen => ErrorCategory::Money,
            Self::MoneyTransferLimitExceeded => ErrorCategory::Money,
            Self::MoneyExternalPaymentError => ErrorCategory::Money,
            Self::MoneyInvalidAccountNumber => ErrorCategory::Money,
            Self::MoneyCurrencyConversionFailed => ErrorCategory::Money,
            Self::MoneyTransactionDeclined => ErrorCategory::Money,
            Self::MoneyFraudDetectionAlert => ErrorCategory::Money,

            // 待办模块错误分类
            Self::TodoNotFound => ErrorCategory::Todo,
            Self::TodoCompleted => ErrorCategory::Todo,
            Self::TodoAlreadyExists => ErrorCategory::Todo,
            Self::TodoExternalService => ErrorCategory::Todo,

            // 待办提醒类错误分类
            Self::TodoReminderInvalidTime => ErrorCategory::Reminder,
            Self::TodoReminderInvalidRecurrence => ErrorCategory::Reminder,
            Self::TodoReminderNotFound => ErrorCategory::Reminder,
            Self::TodoReminderExpired => ErrorCategory::Reminder,
            Self::TodoReminderServiceUnavailable => ErrorCategory::Reminder,

            // 健康模块错误分类
            Self::HealthDataNotFound => ErrorCategory::Health,
            Self::HealthDataInvalid => ErrorCategory::Health,
            Self::HealthGoalNotSet => ErrorCategory::Health,
            Self::HealthGoalAchieved => ErrorCategory::Health,
            Self::HealthGoalProgressInvalid => ErrorCategory::Health,
            Self::HealthServiceConnectionFailed => ErrorCategory::Health,

            // 月经经期类错误分类
            Self::MenstrualCycleNotFound => ErrorCategory::Menstrual,
            Self::MenstrualCycleStartDateInvalid => ErrorCategory::Menstrual,
            Self::MenstrualCycleLengthInvalid => ErrorCategory::Menstrual,
            Self::MenstrualDurationInvalid => ErrorCategory::Menstrual,
            Self::MenstrualPredictionFailed => ErrorCategory::Menstrual,
            Self::MenstrualSymptomInvalid => ErrorCategory::Menstrual,
            Self::MenstrualReminderSetupFailed => ErrorCategory::Menstrual,
            Self::MenstrualDataSyncFailed => ErrorCategory::Menstrual,

            // 环境变量错误分类
            Self::EnvVarEmptyKey => ErrorCategory::Env,
            Self::EnvVarNotPresent => ErrorCategory::Env,
            Self::EnvVarNotUnicode => ErrorCategory::Env,
            Self::EnvVarParseFailure => ErrorCategory::Env,

            // 其他错误分类
            Self::SystemError => ErrorCategory::System,
            Self::SerializationError => ErrorCategory::System,
            Self::DeserializationError => ErrorCategory::System,
        }
    }

    /// 获取模块名称
    pub fn module(&self) -> ErrorModule {
        match self {
            // 基础错误模块
            Self::Success => ErrorModule::Core,
            Self::CommandFailed => ErrorModule::Core,
            Self::ValidationError => ErrorModule::Core,
            Self::DatabaseError => ErrorModule::Core,
            Self::FileError => ErrorModule::Core,
            Self::ConfigError => ErrorModule::Core,
            Self::NetworkError => ErrorModule::Core,
            Self::Unauthorized => ErrorModule::Auth,
            Self::Forbidden => ErrorModule::Auth,
            Self::NotFound => ErrorModule::Core,
            Self::InvalidParameter => ErrorModule::Core,
            Self::AuthenticationFailed => ErrorModule::Auth,
            Self::SessionExpired => ErrorModule::Auth,
            Self::TokenInvalid => ErrorModule::Auth,
            Self::InsufficientPermissions => ErrorModule::Auth,
            Self::RefreshTokenExpired => ErrorModule::Auth,
            Self::InvalidCredentials => ErrorModule::Auth,
            Self::AccountLocked => ErrorModule::Auth,
            Self::AccountNotVerified => ErrorModule::Auth,
            Self::TwoFactorRequired => ErrorModule::Auth,
            Self::TwoFactorFailed => ErrorModule::Auth,
            Self::TokenGenerationFailed => ErrorModule::Auth,
            Self::TokenExpired => ErrorModule::Auth,
            Self::PasswordHashError => ErrorModule::Auth,
            Self::PasswordVerifyError => ErrorModule::Auth,
            Self::PasswordFormatError => ErrorModule::Auth,

            // 财务模块错误模块
            Self::MoneyInsufficientFunds => ErrorModule::Money,
            Self::MoneyPaymentFailed => ErrorModule::Money,
            Self::MoneyTransactionNotFound => ErrorModule::Money,
            Self::MoneyInvalidCurrency => ErrorModule::Money,
            Self::MoneyInvalidAmount => ErrorModule::Money,
            Self::MoneyAccountFrozen => ErrorModule::Money,
            Self::MoneyTransferLimitExceeded => ErrorModule::Money,
            Self::MoneyExternalPaymentError => ErrorModule::Money,
            Self::MoneyInvalidAccountNumber => ErrorModule::Money,
            Self::MoneyCurrencyConversionFailed => ErrorModule::Money,
            Self::MoneyTransactionDeclined => ErrorModule::Money,
            Self::MoneyFraudDetectionAlert => ErrorModule::Money,

            // 待办模块错误模块
            Self::TodoNotFound => ErrorModule::Todo,
            Self::TodoCompleted => ErrorModule::Todo,
            Self::TodoAlreadyExists => ErrorModule::Todo,
            Self::TodoExternalService => ErrorModule::Todo,

            // 待办提醒类错误模块
            Self::TodoReminderInvalidTime => ErrorModule::TodoReminder,
            Self::TodoReminderInvalidRecurrence => ErrorModule::TodoReminder,
            Self::TodoReminderNotFound => ErrorModule::TodoReminder,
            Self::TodoReminderExpired => ErrorModule::TodoReminder,
            Self::TodoReminderServiceUnavailable => ErrorModule::TodoReminder,

            // 健康模块错误模块
            Self::HealthDataNotFound => ErrorModule::Health,
            Self::HealthDataInvalid => ErrorModule::Health,
            Self::HealthGoalNotSet => ErrorModule::Health,
            Self::HealthGoalAchieved => ErrorModule::Health,
            Self::HealthGoalProgressInvalid => ErrorModule::Health,
            Self::HealthServiceConnectionFailed => ErrorModule::Health,

            // 月经经期类错误模块
            Self::MenstrualCycleNotFound => ErrorModule::Menstrual,
            Self::MenstrualCycleStartDateInvalid => ErrorModule::Menstrual,
            Self::MenstrualCycleLengthInvalid => ErrorModule::Menstrual,
            Self::MenstrualDurationInvalid => ErrorModule::Menstrual,
            Self::MenstrualPredictionFailed => ErrorModule::Menstrual,
            Self::MenstrualSymptomInvalid => ErrorModule::Menstrual,
            Self::MenstrualReminderSetupFailed => ErrorModule::Menstrual,
            Self::MenstrualDataSyncFailed => ErrorModule::Menstrual,

            // 环境变量错误模块
            Self::EnvVarEmptyKey => ErrorModule::Env,
            Self::EnvVarNotPresent => ErrorModule::Env,
            Self::EnvVarNotUnicode => ErrorModule::Env,
            Self::EnvVarParseFailure => ErrorModule::Env,

            // 其他错误模块
            Self::SystemError => ErrorModule::System,
            Self::SerializationError => ErrorModule::System,
            Self::DeserializationError => ErrorModule::System,
        }
    }
}

impl From<BusinessCode> for String {
    fn from(code: BusinessCode) -> Self {
        code.as_str()
    }
}
