use serde::{Serialize, Deserialize};

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
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Success => "success",
            Self::Command => "command",
            Self::Validation => "validation",
            Self::Database => "database",
            Self::File => "file",
            Self::Config => "config",
            Self::Network => "network",
            Self::Auth => "auth",
            Self::Resource => "resource",
            Self::Money => "money",
            Self::Todo => "todo",
            Self::Reminder => "reminder",
            Self::Health => "health",
            Self::Menstrual => "menstrual",
            Self::Env => "env",
            Self::System => "system",
        }
    }
}

impl From<ErrorCategory> for String {
    fn from(category: ErrorCategory) -> Self {
        category.as_str().to_string()
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
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Core => "core",
            Self::Money => "money",
            Self::Todo => "todo",
            Self::TodoReminder => "todo_reminder",
            Self::Health => "health",
            Self::Menstrual => "menstrual",
            Self::Env => "env",
            Self::System => "system",
            Self::Auth => "auth",
        }
    }
}

impl From<ErrorModule> for String {
    fn from(module: ErrorModule) -> Self {
        module.as_str().to_string()
    }
}


/// 统一业务错误码
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BusinessCode {
    // ===== 基础错误码 (0-999) =====
    /// 成功
    Success = 0,

    /// 命令执行失败
    CommandFailed = 100,

    /// 验证错误
    ValidationError = 101,

    /// 数据库错误
    DatabaseError = 102,

    /// 文件操作错误
    FileError = 103,

    /// 配置错误
    ConfigError = 104,

    /// 网络错误
    NetworkError = 105,

    /// 无效参数
    InvalidParameter = 400,

    /// 未授权
    Unauthorized = 401,

    /// 认证失败
    AuthenticationFailed = 402,

    /// 禁止访问
    Forbidden = 403,

    /// 未找到
    NotFound = 404,

    /// 会话过期
    SessionExpired = 406,

    /// 令牌无效
    TokenInvalid = 407,

    /// 权限不足
    InsufficientPermissions = 408,

    // ===== 财务模块错误码 (1000-1999) =====
    /// 余额不足
    MoneyInsufficientFunds = 1001,

    /// 支付失败
    MoneyPaymentFailed = 1002,

    /// 交易未找到
    MoneyTransactionNotFound = 1003,

    /// 无效的货币类型
    MoneyInvalidCurrency = 1004,

    /// 无效的金额
    MoneyInvalidAmount = 1005,

    /// 账户已冻结
    MoneyAccountFrozen = 1006,

    /// 转账限制
    MoneyTransferLimitExceeded = 1007,

    /// 外部支付服务错误
    MoneyExternalPaymentError = 1008,

    // ===== 待办模块错误码 (2000-2999) =====
    /// 待办未找到
    TodoNotFound = 2001,

    /// 待办已完成
    TodoCompleted = 2002,

    /// 待办已存在
    TodoAlreadyExists = 2003,

    /// 待办外部服务错误
    TodoExternalService = 2004,

    // ===== 待办提醒类错误码 (2100-2199) =====
    /// 提醒时间无效
    TodoReminderInvalidTime = 2101,

    /// 提醒重复设置无效
    TodoReminderInvalidRecurrence = 2102,

    /// 提醒未找到
    TodoReminderNotFound = 2103,

    /// 提醒已过期
    TodoReminderExpired = 2104,

    /// 提醒服务不可用
    TodoReminderServiceUnavailable = 2105,

    // ===== 环境变量错误码 (3000-3999) =====
    /// 环境变量键为空
    EnvVarEmptyKey = 3001,

    /// 环境变量未设置
    EnvVarNotPresent = 3002,

    /// 环境变量非 Unicode
    EnvVarNotUnicode = 3003,

    /// 环境变量解析失败
    EnvVarParseFailure = 3004,

    // ===== 健康模块错误码 (4000-4999) =====
    /// 健康数据未找到
    HealthDataNotFound = 4001,

    /// 健康数据无效
    HealthDataInvalid = 4002,

    /// 健康目标未设置
    HealthGoalNotSet = 4003,

    /// 健康目标已达成
    HealthGoalAchieved = 4004,

    /// 健康目标进度无效
    HealthGoalProgressInvalid = 4005,

    /// 健康服务连接失败
    HealthServiceConnectionFailed = 4006,

    // ===== 月经经期类错误码 (4100-4199) =====
    /// 经期记录未找到
    MenstrualCycleNotFound = 4101,

    /// 经期开始日期无效
    MenstrualCycleStartDateInvalid = 4102,

    /// 经期周期长度无效
    MenstrualCycleLengthInvalid = 4103,

    /// 经期持续时间无效
    MenstrualDurationInvalid = 4104,

    /// 经期预测失败
    MenstrualPredictionFailed = 4105,

    /// 经期症状记录无效
    MenstrualSymptomInvalid = 4106,

    /// 经期提醒设置失败
    MenstrualReminderSetupFailed = 4107,

    /// 经期数据同步失败
    MenstrualDataSyncFailed = 4108,

    /// 密码哈希错误
    PasswordHashError = 6001,

    /// 密码验证错误
    PasswordVerifyError = 6002,

    /// 密码格式错误
    PasswordFormatError = 6003,

    // ===== 其他错误码 (9000-9999) =====
    /// 系统错误
    SystemError = 9999,
}

impl BusinessCode {
    /// 获取错误码字符串（6 位格式）
    pub fn as_str(&self) -> &'static str {
        match self {
            // 基础错误码
            Self::Success => "000000",
            Self::CommandFailed => "000100",
            Self::ValidationError => "000101",
            Self::DatabaseError => "000102",
            Self::FileError => "000103",
            Self::ConfigError => "000104",
            Self::NetworkError => "000105",
            Self::Unauthorized => "000401",
            Self::Forbidden => "000403",
            Self::NotFound => "000404",
            Self::InvalidParameter => "000400",
            Self::AuthenticationFailed => "000402",
            Self::SessionExpired => "000406",
            Self::TokenInvalid => "000407",
            Self::InsufficientPermissions => "000408",
            Self::PasswordHashError => "006001",
            Self::PasswordVerifyError => "006002",
            Self::PasswordFormatError => "006003",

            // 财务模块错误码
            Self::MoneyInsufficientFunds => "001001",
            Self::MoneyPaymentFailed => "001002",
            Self::MoneyTransactionNotFound => "001003",
            Self::MoneyInvalidCurrency => "001004",
            Self::MoneyInvalidAmount => "001005",
            Self::MoneyAccountFrozen => "001006",
            Self::MoneyTransferLimitExceeded => "001007",
            Self::MoneyExternalPaymentError => "001008",

            // 待办模块错误码
            Self::TodoNotFound => "002001",
            Self::TodoCompleted => "002002",
            Self::TodoAlreadyExists => "002003",
            Self::TodoExternalService => "002004",

            // 待办提醒类错误码
            Self::TodoReminderInvalidTime => "002101",
            Self::TodoReminderInvalidRecurrence => "002102",
            Self::TodoReminderNotFound => "002103",
            Self::TodoReminderExpired => "002104",
            Self::TodoReminderServiceUnavailable => "002105",

            // 健康模块错误码
            Self::HealthDataNotFound => "004001",
            Self::HealthDataInvalid => "004002",
            Self::HealthGoalNotSet => "004003",
            Self::HealthGoalAchieved => "004004",
            Self::HealthGoalProgressInvalid => "004005",
            Self::HealthServiceConnectionFailed => "004006",

            // 月经经期类错误码
            Self::MenstrualCycleNotFound => "004101",
            Self::MenstrualCycleStartDateInvalid => "004102",
            Self::MenstrualCycleLengthInvalid => "004103",
            Self::MenstrualDurationInvalid => "004104",
            Self::MenstrualPredictionFailed => "004105",
            Self::MenstrualSymptomInvalid => "004106",
            Self::MenstrualReminderSetupFailed => "004107",
            Self::MenstrualDataSyncFailed => "004108",

            // 环境变量错误码
            Self::EnvVarEmptyKey => "003001",
            Self::EnvVarNotPresent => "003002",
            Self::EnvVarNotUnicode => "003003",
            Self::EnvVarParseFailure => "003004",

            // 其他错误码
            Self::SystemError => "009999",
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
        }
    }
}

impl From<BusinessCode> for String {
    fn from(code: BusinessCode) -> Self {
        code.as_str().to_string()
    }
}
