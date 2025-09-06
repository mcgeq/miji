use std::{fmt, str::FromStr};

use chrono::{DateTime, FixedOffset, NaiveDate};
use common::{
    BusinessCode,
    crud::service::{parse_enum_filed, parse_json, serialize_enum},
    error::AppError,
    utils::{date::DateUtils, uuid::McgUuid},
};
use sea_orm::{ActiveValue::Set, FromQueryResult, prelude::Decimal};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::dto::{
    account::{AccountResponseWithRelations, AccountType, AccountWithRelations, CurrencyInfo},
    family_member::FamilyMemberResponse,
};

#[derive(Debug, Deserialize, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct IncomeExpense {
    pub income: AccountTypeSummary,
    pub expense: AccountTypeSummary,
    pub transfer: TransferSummary,
}

#[derive(Debug, Deserialize, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct AccountTypeSummary {
    pub total: Decimal,
    pub transfer: Decimal,
    #[serde(default)]
    pub bank_savings: Decimal,
    #[serde(default)]
    pub cash: Decimal,
    #[serde(default)]
    pub credit_card: Decimal,
    #[serde(default)]
    pub investment: Decimal,
    #[serde(default)]
    pub alipay: Decimal,
    #[serde(default)]
    pub wechat: Decimal,
    #[serde(default)]
    pub cloud_quick_pass: Decimal,
    #[serde(default)]
    pub other: Decimal,
}

#[derive(Debug, Deserialize, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct TransferSummary {
    pub income: Decimal,
    pub expense: Decimal,
}

// Intermediate struct to map flat query results
#[derive(Debug, Serialize, Deserialize, FromQueryResult, Default)]
#[serde(rename_all = "camelCase")]
pub struct IncomeExpenseRaw {
    total: Decimal,
    total_expense: Decimal,
    transfer_income: Decimal,
    transfer_expense: Decimal,
    bank_savings_income: Decimal,
    bank_savings_expense: Decimal,
    cash_income: Decimal,
    cash_expense: Decimal,
    credit_card_income: Decimal,
    credit_card_expense: Decimal,
    investment_income: Decimal,
    investment_expense: Decimal,
    alipay_income: Decimal,
    alipay_expense: Decimal,
    wechat_income: Decimal,
    wechat_expense: Decimal,
    cloud_quick_pass_income: Decimal,
    cloud_quick_pass_expense: Decimal,
    other_income: Decimal,
    other_expense: Decimal,
}

impl From<IncomeExpenseRaw> for IncomeExpense {
    fn from(raw: IncomeExpenseRaw) -> Self {
        IncomeExpense {
            income: AccountTypeSummary {
                total: raw.total,
                transfer: raw.transfer_income,
                bank_savings: raw.bank_savings_income,
                cash: raw.cash_income,
                credit_card: raw.credit_card_income,
                investment: raw.investment_income,
                alipay: raw.alipay_income,
                wechat: raw.wechat_income,
                cloud_quick_pass: raw.cloud_quick_pass_income,
                other: raw.other_income,
            },
            expense: AccountTypeSummary {
                total: raw.total_expense,
                transfer: raw.transfer_expense,
                bank_savings: raw.bank_savings_expense,
                cash: raw.cash_expense,
                credit_card: raw.credit_card_expense,
                investment: raw.investment_expense,
                alipay: raw.alipay_expense,
                wechat: raw.wechat_expense,
                cloud_quick_pass: raw.cloud_quick_pass_expense,
                other: raw.other_expense,
            },
            transfer: TransferSummary {
                income: raw.transfer_income,
                expense: raw.transfer_expense,
            },
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "PascalCase")] // 注意要和前端 z.enum 值匹配大小写
pub enum TransactionStatus {
    Pending,
    Completed,
    Reversed,
}

impl fmt::Display for TransactionStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            TransactionStatus::Pending => "Pending",
            TransactionStatus::Completed => "Completed",
            TransactionStatus::Reversed => "Reversed",
        };
        write!(f, "{s}")
    }
}

impl FromStr for TransactionStatus {
    type Err = AppError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Pending" => Ok(TransactionStatus::Pending),
            "Completed" => Ok(TransactionStatus::Completed),
            "Reversed" => Ok(TransactionStatus::Reversed),
            _ => Err(AppError::simple(
                BusinessCode::InvalidParameter,
                format!("无效的交易状态: {s}"),
            )),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "PascalCase")]
pub enum TransactionType {
    Income,
    Expense,
    Transfer,
}

impl fmt::Display for TransactionType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            TransactionType::Income => "Income",
            TransactionType::Expense => "Expense",
            TransactionType::Transfer => "Transfer",
        };
        write!(f, "{s}")
    }
}

impl FromStr for TransactionType {
    type Err = AppError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Income" => Ok(TransactionType::Income),
            "Expense" => Ok(TransactionType::Expense),
            "Transfer" => Ok(TransactionType::Transfer),
            _ => Err(AppError::simple(
                BusinessCode::InvalidParameter,
                format!("无效的交易类型: {s}"),
            )),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum PaymentMethod {
    Savings,        // 储蓄账户
    Cash,           // 现金支付
    BankTransfer,   // 银行转账
    CreditCard,     // 信用卡支付
    WeChat,         // 微信支付
    Alipay,         // 支付宝支付
    CloudQuickPass, // 云闪付
    Other,          // 其他方式
}

impl fmt::Display for PaymentMethod {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            PaymentMethod::Savings => "Savings",
            PaymentMethod::Cash => "Cash",
            PaymentMethod::BankTransfer => "BankTransfer",
            PaymentMethod::CreditCard => "CreditCard",
            PaymentMethod::WeChat => "WeChat",
            PaymentMethod::Alipay => "Alipay",
            PaymentMethod::CloudQuickPass => "CloudQuickPass",
            PaymentMethod::Other => "Other",
        };
        write!(f, "{s}")
    }
}

impl FromStr for PaymentMethod {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Savings" => Ok(PaymentMethod::Savings),
            "Cash" => Ok(PaymentMethod::Cash),
            "BankTransfer" => Ok(PaymentMethod::BankTransfer),
            "CreditCard" => Ok(PaymentMethod::CreditCard),
            "WeChat" => Ok(PaymentMethod::WeChat),
            "Alipay" => Ok(PaymentMethod::Alipay),
            "CloudQuickPass" => Ok(PaymentMethod::CloudQuickPass),
            "Other" => Ok(PaymentMethod::Other),
            _ => Err(format!("Unknown PaymentMethod: {s}")),
        }
    }
}

#[derive(Debug, Clone, Validate, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateTransactionRequest {
    pub transaction_type: TransactionType,
    pub transaction_status: TransactionStatus,
    pub date: DateTime<FixedOffset>,

    #[validate(custom(function = "validate_amount"))]
    pub amount: Decimal,

    #[validate(length(equal = 3))]
    pub currency: String,

    #[validate(length(min = 0, max = 1024))]
    pub description: String,

    #[validate(length(max = 1024))]
    pub notes: Option<String>,

    #[validate(length(equal = 38))]
    pub account_serial_num: String,

    #[validate(length(equal = 38))]
    pub to_account_serial_num: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub category: String,

    #[validate(length(max = 64))]
    pub sub_category: Option<String>,

    pub tags: Option<serde_json::Value>,
    pub split_members: Option<serde_json::Value>,

    pub payment_method: PaymentMethod,

    pub actual_payer_account: AccountType,

    #[validate(length(max = 38))]
    pub related_transaction_serial_num: Option<String>,
}

impl TryFrom<CreateTransactionRequest> for entity::transactions::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: CreateTransactionRequest) -> Result<Self, Self::Error> {
        value.validate()?;
        let serial_num = McgUuid::uuid(38);

        // 获取当前时间
        let now = DateUtils::local_now();

        Ok(entity::transactions::ActiveModel {
            serial_num: Set(serial_num),
            transaction_type: Set(serialize_enum(&value.transaction_type)),
            transaction_status: Set(serialize_enum(&value.transaction_status)),
            date: Set(value.date),
            amount: Set(value.amount),
            refund_amount: Set(Decimal::ZERO),
            currency: Set(value.currency),
            description: Set(value.description),
            notes: Set(value.notes),
            account_serial_num: Set(value.account_serial_num),
            to_account_serial_num: Set(value.to_account_serial_num),
            category: Set(value.category),
            sub_category: Set(value.sub_category),
            tags: Set(Some(parse_json(
                &value.tags,
                "tags",
                serde_json::Value::Null,
            ))),
            split_members: Set(Some(parse_json(
                &value.split_members,
                "split_members",
                serde_json::Value::Null,
            ))),
            payment_method: Set(serialize_enum(&value.payment_method)),
            actual_payer_account: Set(serialize_enum(&value.actual_payer_account)),
            related_transaction_serial_num: Set(value.related_transaction_serial_num),
            is_deleted: Set(false),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct UpdateTransactionRequest {
    pub transaction_type: Option<TransactionType>,
    pub transaction_status: Option<TransactionStatus>,

    pub date: Option<DateTime<FixedOffset>>,

    #[validate(custom(function = "validate_amount"))]
    pub amount: Option<Decimal>,

    #[validate(length(min = 1, max = 16))]
    pub currency: Option<String>,

    #[validate(length(min = 1, max = 1024))]
    pub description: Option<String>,

    #[validate(length(max = 1024))]
    pub notes: Option<String>,

    #[validate(length(equal = 38))]
    pub account_serial_num: Option<String>,

    #[validate(length(equal = 38))]
    pub to_account_serial_num: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub category: Option<String>,

    #[validate(length(max = 64))]
    pub sub_category: Option<String>,

    pub tags: Option<serde_json::Value>,

    pub split_members: Option<serde_json::Value>,

    pub payment_method: Option<PaymentMethod>,

    pub actual_payer_account: Option<AccountType>,

    #[validate(length(max = 38))]
    pub related_transaction_serial_num: Option<String>,

    pub is_deleted: Option<bool>,
}

impl TryFrom<UpdateTransactionRequest> for entity::transactions::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: UpdateTransactionRequest) -> Result<Self, Self::Error> {
        value.validate()?;
        // 获取当前时间
        let now = DateUtils::local_now();

        let mut model = entity::transactions::ActiveModel {
            ..Default::default() // 初始化为空模型
        };

        // 应用 DTO 中的字段到 ActiveModel
        if let Some(transaction_type) = value.transaction_type {
            model.transaction_type = Set(serialize_enum(&transaction_type));
        }
        if let Some(transaction_status) = value.transaction_status {
            model.transaction_status = Set(serialize_enum(&transaction_status));
        }
        if let Some(date) = value.date {
            model.date = Set(date);
        }
        if let Some(amount) = value.amount {
            model.amount = Set(amount);
        }
        if let Some(currency) = value.currency {
            model.currency = Set(currency);
        }
        if let Some(description) = value.description {
            model.description = Set(description);
        }
        if let Some(notes) = value.notes {
            model.notes = Set(Some(notes));
        }
        if let Some(account_serial_num) = value.account_serial_num {
            model.account_serial_num = Set(account_serial_num);
        }
        if let Some(to_account_serial_num) = value.to_account_serial_num {
            model.to_account_serial_num = Set(Some(to_account_serial_num));
        }
        if let Some(category) = value.category {
            model.category = Set(category);
        }
        if let Some(sub_category) = value.sub_category {
            model.sub_category = Set(Some(sub_category));
        }
        if let Some(tags) = value.tags {
            model.tags = Set(Some(tags));
        }
        if let Some(split_members) = value.split_members {
            model.split_members = Set(Some(split_members));
        }
        if let Some(payment_method) = value.payment_method {
            model.payment_method = Set(serialize_enum(&payment_method));
        }
        if let Some(actual_payer_account) = value.actual_payer_account {
            model.actual_payer_account = Set(serialize_enum(&actual_payer_account));
        }
        if let Some(related_transaction_serial_num) = value.related_transaction_serial_num {
            model.related_transaction_serial_num = Set(Some(related_transaction_serial_num));
        }
        if let Some(is_deleted) = value.is_deleted {
            model.is_deleted = Set(is_deleted);
        }

        // 更新 updated_at 字段
        model.updated_at = Set(Some(now));

        Ok(model)
    }
}

#[derive(Debug, Clone, Validate, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransferRequest {
    transaction_type: TransactionType,
    #[validate(custom(function = "validate_amount"))]
    pub amount: Decimal,

    #[validate(length(equal = 38))]
    pub account_serial_num: String,

    #[validate(length(equal = 38))]
    pub to_account_serial_num: String,

    pub payment_method: PaymentMethod,

    #[validate(length(equal = 3))]
    pub currency: String,
    #[validate(length(min = 1, max = 64))]
    pub category: Option<String>,

    #[validate(length(max = 64))]
    pub sub_category: Option<String>,

    pub date: Option<DateTime<FixedOffset>>,
    #[validate(length(min = 0, max = 1024))]
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionWithRelations {
    pub transaction: entity::transactions::Model,
    pub account: AccountWithRelations,
    pub currency: entity::currency::Model,
    pub family_member: Vec<entity::family_member::Model>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransactionResponse {
    pub serial_num: String,
    pub transaction_type: TransactionType,
    pub transaction_status: TransactionStatus,
    pub date: DateTime<FixedOffset>,
    pub amount: Decimal,
    pub refund_amount: Decimal,
    pub account: AccountResponseWithRelations,
    pub currency: CurrencyInfo,
    pub description: String,
    pub notes: Option<String>,
    pub account_serial_num: String,
    pub to_account_serial_num: Option<String>,
    pub category: String,
    pub sub_category: Option<String>,
    pub tags: Option<serde_json::Value>,
    pub split_members: Option<Vec<FamilyMemberResponse>>,
    pub payment_method: PaymentMethod,
    pub actual_payer_account: AccountType,
    pub related_transaction_serial_num: Option<String>,
    pub is_deleted: bool,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

impl From<TransactionWithRelations> for TransactionResponse {
    fn from(model: TransactionWithRelations) -> Self {
        let trans = model.transaction;
        let acct = model.account;
        let cny = model.currency;
        let family_member = model.family_member;
        Self {
            serial_num: trans.serial_num,
            transaction_type: parse_enum_filed(
                &trans.transaction_type,
                "transaction_type",
                TransactionType::Income,
            ),
            transaction_status: parse_enum_filed(
                &trans.transaction_status,
                "transaction_status",
                TransactionStatus::Pending,
            ),
            date: trans.date,
            amount: trans.amount,
            refund_amount: trans.refund_amount,
            account: AccountResponseWithRelations::from(acct),
            currency: CurrencyInfo::from(cny),
            description: trans.description,
            notes: trans.notes,
            account_serial_num: trans.account_serial_num,
            to_account_serial_num: trans.to_account_serial_num,
            category: trans.category,
            sub_category: trans.sub_category,
            tags: trans.tags,
            split_members: if family_member.is_empty() {
                None
            } else {
                Some(
                    family_member
                        .iter()
                        .map(FamilyMemberResponse::from)
                        .collect::<Vec<FamilyMemberResponse>>(),
                )
            },
            payment_method: parse_enum_filed(
                &trans.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_enum_filed(
                &trans.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: trans.related_transaction_serial_num,
            is_deleted: trans.is_deleted,
            created_at: trans.created_at,
            updated_at: trans.updated_at,
        }
    }
}

fn validate_amount(amount: &Decimal) -> Result<(), validator::ValidationError> {
    if amount.is_sign_negative() {
        return Err(validator::ValidationError::new(
            "amount_must_be_non_negative",
        ));
    }
    Ok(())
}

// 日期格式验证 - 修复参数类型
#[allow(dead_code)]
fn validate_date(date: &str) -> Result<(), validator::ValidationError> {
    NaiveDate::parse_from_str(date, "%Y-%m-%d")
        .map(|_| ())
        .map_err(|_| validator::ValidationError::new("invalid_date_format"))
}
