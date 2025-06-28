use std::fmt;

#[derive(Debug, Clone, Copy)]
pub enum BusinessCode {
    Success = 000000,                    // 成功
    SystemError = 999999,                // 系统错误
    InvalidParameter = 400001,           // Invalid parameter
    ValidationFailure = 400004,          // Field validation failure
    ResourceNotFound = 404001,           // Resource not found
    Unauthorized = 401001,               // Unauthorized
    Forbidden = 403001,                  // Forbidden
    InternalServerError = 500001,        // Internal server error
    InvalidData = 400002,                // Invalid data
    Conflict = 409001,                   // Conflict
    ServiceUnavailable = 503001,         // Service unavailable
    DuplicateResource = 409002,          // Duplicate resource / already exists
    OperationTimeout = 504001,           // Operation timed out
    RateLimitExceeded = 429001,          // Rate limit exceeded / too many requests
    ValidationFailed = 400003,           // Validation failed
    AuthenticationFailed = 401002,       // Authentication failed
    PermissionDenied = 403002,           // Permission denied
    DataConflict = 409003,               // Data conflict (e.g., optimistic lock)
    NotAcceptable = 406001,              // Not acceptable request
    DatabaseInitFailure = 500002,        // Database initialization failed
    DatabaseConnectionFailure = 500003,  // Database connection failed
    DatabaseQueryFailure = 500004,       // Database query execution failed
    DatabaseTransactionFailure = 500005, // Database transaction failed
    DatabasePoolFailure = 500006,        // Database connection pool failed
    EnvVarEmptyKey = 500007,             // Environment variable key is empty
    EnvVarNotPresent = 500008,           // Environment variable is not set
    EnvVarNotUnicode = 500009,           // Environment variable is not valid Unicode
    EnvVarParseFailure = 500010,         // Environment variable parsing failed
}

impl fmt::Display for BusinessCode {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", *self as i32)
    }
}

impl From<BusinessCode> for i32 {
    fn from(value: BusinessCode) -> Self {
        value as i32
    }
}

impl From<BusinessCode> for String {
    fn from(value: BusinessCode) -> Self {
        match value {
            BusinessCode::Success => "000000".to_string(),
            _ => value.to_string(),
        }
    }
}

impl BusinessCode {
    pub fn description(&self) -> &'static str {
        match self {
            BusinessCode::Success => "Success",
            BusinessCode::SystemError => "System error",
            BusinessCode::InvalidParameter => "Invalid input parameters.",
            BusinessCode::ResourceNotFound => "The requested resource was not found.",
            BusinessCode::Unauthorized => "User is not authorized to access this resource.",
            BusinessCode::Forbidden => "Access to the resource is forbidden.",
            BusinessCode::InternalServerError => "An internal server error occurred.",
            BusinessCode::InvalidData => "The provided data is invalid or malformed.",
            BusinessCode::Conflict => "There is a conflict with the current state of the resource.",
            BusinessCode::ServiceUnavailable => "The service is temporarily unavailable.",
            BusinessCode::DuplicateResource => "The resource already exists.",
            BusinessCode::OperationTimeout => "The operation timed out.",
            BusinessCode::RateLimitExceeded => "Too many requests; you have been rate limited.",
            BusinessCode::ValidationFailed => "Business validation failed.",
            BusinessCode::AuthenticationFailed => "Authentication failed; please log in again.",
            BusinessCode::PermissionDenied => "You do not have permission to perform this action.",
            BusinessCode::DataConflict => "Data conflict detected (e.g., version mismatch).",
            BusinessCode::NotAcceptable => "Request format not acceptable.",
            BusinessCode::DatabaseInitFailure => "Database initialization failed",
            BusinessCode::DatabaseConnectionFailure => "Database connection failed",
            BusinessCode::DatabaseQueryFailure => "Database query execution failed",
            BusinessCode::DatabaseTransactionFailure => "Database transaction failed",
            BusinessCode::DatabasePoolFailure => "Database connection pool failed",
            BusinessCode::ValidationFailure => "Field validation failed.",
            BusinessCode::EnvVarEmptyKey => "Environment variable key is empty",
            BusinessCode::EnvVarNotPresent => "Environment variable is not set",
            BusinessCode::EnvVarNotUnicode => "Environment variable is not valid Unicode",
            BusinessCode::EnvVarParseFailure => "Environment variable parsing failed",
        }
    }
}
