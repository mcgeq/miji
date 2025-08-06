use common::{
    BusinessCode,
    error::{ ErrorExt},
};
use snafu::{Backtrace, Snafu};

/// 财务相关错误
#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum MoneyError {
    #[snafu(display("Insufficient funds: current balance {}", balance))]
    InsufficientFunds {
        balance: f64,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Payment failed: {}", reason))]
    PaymentFailed {
        reason: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Transaction not found: {}", transaction_id))]
    TransactionNotFound {
        transaction_id: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Invalid currency: {}", currency))]
    InvalidCurrency {
        currency: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Invalid amount: {}", amount))]
    InvalidAmount {
        amount: f64,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Account frozen: {}", account_id))]
    AccountFrozen {
        account_id: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Transfer limit exceeded: limit={}, amount={}", limit, amount))]
    TransferLimitExceeded {
        limit: f64,
        amount: f64,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("External payment service error: {}", service))]
    ExternalPaymentError {
        service: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Invalid account number: {}", account_number))]
    InvalidAccountNumber {
        account_number: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Currency conversion failed: {}", reason))]
    CurrencyConversionFailed {
        reason: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Transaction declined: {}", reason))]
    TransactionDeclined {
        reason: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },

    #[snafu(display("Fraud detection alert: {}", alert))]
    FraudDetectionAlert {
        alert: String,
        #[snafu(backtrace)]
        backtrace: Backtrace,
    },
}

impl ErrorExt for MoneyError {
    fn business_code(&self) -> BusinessCode {
        match self {
            Self::InsufficientFunds { .. } => BusinessCode::MoneyInsufficientFunds,
            Self::PaymentFailed { .. } => BusinessCode::MoneyPaymentFailed,
            Self::TransactionNotFound { .. } => BusinessCode::MoneyTransactionNotFound,
            Self::InvalidCurrency { .. } => BusinessCode::MoneyInvalidCurrency,
            Self::InvalidAmount { .. } => BusinessCode::MoneyInvalidAmount,
            Self::AccountFrozen { .. } => BusinessCode::MoneyAccountFrozen,
            Self::TransferLimitExceeded { .. } => BusinessCode::MoneyTransferLimitExceeded,
            Self::ExternalPaymentError { .. } => BusinessCode::MoneyExternalPaymentError,
            Self::InvalidAccountNumber { .. } => BusinessCode::MoneyInvalidAccountNumber,
            Self::CurrencyConversionFailed { .. } => BusinessCode::MoneyCurrencyConversionFailed,
            Self::TransactionDeclined { .. } => BusinessCode::MoneyTransactionDeclined,
            Self::FraudDetectionAlert { .. } => BusinessCode::MoneyFraudDetectionAlert,
        }
    }

    fn description(&self) -> &'static str {
        self.business_code().description()
    }

    fn extra_data(&self) -> Option<serde_json::Value> {
        match self {
            Self::InsufficientFunds { balance, .. } => {
                Some(serde_json::json!({ "balance": balance }))
            }
            Self::PaymentFailed { reason, .. } => Some(serde_json::json!({ "reason": reason })),
            Self::TransactionNotFound { transaction_id, .. } => {
                Some(serde_json::json!({ "transaction_id": transaction_id }))
            }
            Self::InvalidCurrency { currency, .. } => {
                Some(serde_json::json!({ "currency": currency }))
            }
            Self::InvalidAmount { amount, .. } => Some(serde_json::json!({ "amount": amount })),
            Self::AccountFrozen { account_id, .. } => {
                Some(serde_json::json!({ "account_id": account_id }))
            }
            Self::TransferLimitExceeded { limit, amount, .. } => {
                Some(serde_json::json!({ "limit": limit, "amount": amount }))
            }
            Self::ExternalPaymentError { service, .. } => {
                Some(serde_json::json!({ "service": service }))
            }
            Self::InvalidAccountNumber { account_number, .. } => {
                Some(serde_json::json!({ "account_number": account_number }))
            }
            Self::CurrencyConversionFailed { reason, .. } => {
                Some(serde_json::json!({ "reason": reason }))
            }
            Self::TransactionDeclined { reason, .. } => {
                Some(serde_json::json!({ "reason": reason }))
            }
            Self::FraudDetectionAlert { alert, .. } => Some(serde_json::json!({ "alert": alert })),
        }
    }

    fn backtrace(&self) -> Option<Backtrace> {
        match self {
            Self::InsufficientFunds { backtrace, .. } => Some(backtrace.clone()),
            Self::PaymentFailed { backtrace, .. } => Some(backtrace.clone()),
            Self::TransactionNotFound { backtrace, .. } => Some(backtrace.clone()),
            Self::InvalidCurrency { backtrace, .. } => Some(backtrace.clone()),
            Self::InvalidAmount { backtrace, .. } => Some(backtrace.clone()),
            Self::AccountFrozen { backtrace, .. } => Some(backtrace.clone()),
            Self::TransferLimitExceeded { backtrace, .. } => Some(backtrace.clone()),
            Self::ExternalPaymentError { backtrace, .. } => Some(backtrace.clone()),
            Self::InvalidAccountNumber { backtrace, .. } => Some(backtrace.clone()),
            Self::CurrencyConversionFailed { backtrace, .. } => Some(backtrace.clone()),
            Self::TransactionDeclined { backtrace, .. } => Some(backtrace.clone()),
            Self::FraudDetectionAlert { backtrace, .. } => Some(backtrace.clone()),
        }
    }
}
