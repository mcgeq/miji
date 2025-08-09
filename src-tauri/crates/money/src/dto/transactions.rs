use chrono::NaiveDate;
use common::utils::date::DateUtils;
use sea_orm::{ActiveValue::Set, prelude::Decimal};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Validate, Serialize, Deserialize)]
pub struct CreateTransactionRequest {
    #[validate(length(min = 1, max = 64))]
    pub serial_num: String,

    #[validate(length(min = 1, max = 32))]
    pub transaction_type: String,

    #[validate(length(min = 1, max = 32))]
    pub transaction_status: String,

    #[validate(custom(function = "validate_date"))]
    pub date: String,

    #[validate(custom(function = "validate_amount"))]
    pub amount: Decimal,

    #[validate(length(min = 1, max = 16))]
    pub currency: String,

    #[validate(length(min = 1, max = 1024))]
    pub description: String,

    #[validate(length(max = 1024))]
    pub notes: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub account_serial_num: String,

    #[validate(length(min = 1, max = 64))]
    pub category: String,

    #[validate(length(max = 64))]
    pub sub_category: Option<String>,

    #[validate(length(max = 256))]
    pub tags: Option<String>,

    #[validate(length(max = 1024))]
    pub split_members: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub payment_method: String,

    #[validate(length(min = 1, max = 64))]
    pub actual_payer_account: String,

    #[validate(length(max = 64))]
    pub related_transaction_serial_num: Option<String>,
}

impl From<CreateTransactionRequest> for entity::transactions::ActiveModel {
    fn from(request: CreateTransactionRequest) -> Self {
        let now = DateUtils::current_datetime_local_fixed().to_string();

        entity::transactions::ActiveModel {
            serial_num: Set(request.serial_num),
            transaction_type: Set(request.transaction_type),
            transaction_status: Set(request.transaction_status),
            date: Set(request.date),
            amount: Set(request.amount),
            currency: Set(request.currency),
            description: Set(request.description),
            notes: Set(request.notes),
            account_serial_num: Set(request.account_serial_num),
            category: Set(request.category),
            sub_category: Set(request.sub_category),
            tags: Set(request.tags),
            split_members: Set(request.split_members),
            payment_method: Set(request.payment_method),
            actual_payer_account: Set(request.actual_payer_account),
            related_transaction_serial_num: Set(request.related_transaction_serial_num),
            is_deleted: Set(0), // 默认未删除
            created_at: Set(now.clone()),
            updated_at: Set(Some(now)),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct UpdateTransactionRequest {
    #[validate(length(min = 1, max = 32))]
    pub transaction_type: Option<String>,

    #[validate(length(min = 1, max = 32))]
    pub transaction_status: Option<String>,

    #[validate(custom(function = "validate_date"))]
    pub date: Option<String>,

    #[validate(custom(function = "validate_amount"))]
    pub amount: Option<Decimal>,

    #[validate(length(min = 1, max = 16))]
    pub currency: Option<String>,

    #[validate(length(min = 1, max = 1024))]
    pub description: Option<String>,

    #[validate(length(max = 1024))]
    pub notes: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub account_serial_num: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub category: Option<String>,

    #[validate(length(max = 64))]
    pub sub_category: Option<String>,

    #[validate(length(max = 256))]
    pub tags: Option<String>,

    #[validate(length(max = 1024))]
    pub split_members: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub payment_method: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub actual_payer_account: Option<String>,

    #[validate(length(max = 64))]
    pub related_transaction_serial_num: Option<String>,

    #[validate(range(min = 0, max = 1))]
    pub is_deleted: Option<i32>,
}

impl UpdateTransactionRequest {
    pub fn apply_to_model(&self, model: &mut entity::transactions::ActiveModel) {
        let now = DateUtils::current_datetime_local_fixed().to_string();

        if let Some(transaction_type) = &self.transaction_type {
            model.transaction_type = Set(transaction_type.clone());
        }
        if let Some(transaction_status) = &self.transaction_status {
            model.transaction_status = Set(transaction_status.clone());
        }
        if let Some(date) = &self.date {
            model.date = Set(date.clone());
        }
        if let Some(amount) = &self.amount {
            model.amount = Set(*amount);
        }
        if let Some(currency) = &self.currency {
            model.currency = Set(currency.clone());
        }
        if let Some(description) = &self.description {
            model.description = Set(description.clone());
        }
        if let Some(notes) = &self.notes {
            model.notes = Set(Some(notes.clone()));
        }
        if let Some(account_serial_num) = &self.account_serial_num {
            model.account_serial_num = Set(account_serial_num.clone());
        }
        if let Some(category) = &self.category {
            model.category = Set(category.clone());
        }
        if let Some(sub_category) = &self.sub_category {
            model.sub_category = Set(Some(sub_category.clone()));
        }
        if let Some(tags) = &self.tags {
            model.tags = Set(Some(tags.clone()));
        }
        if let Some(split_members) = &self.split_members {
            model.split_members = Set(Some(split_members.clone()));
        }
        if let Some(payment_method) = &self.payment_method {
            model.payment_method = Set(payment_method.clone());
        }
        if let Some(actual_payer_account) = &self.actual_payer_account {
            model.actual_payer_account = Set(actual_payer_account.clone());
        }
        if let Some(related_transaction_serial_num) = &self.related_transaction_serial_num {
            model.related_transaction_serial_num =
                Set(Some(related_transaction_serial_num.clone()));
        }
        if let Some(is_deleted) = self.is_deleted {
            model.is_deleted = Set(is_deleted);
        }

        // 更新 updated_at 字段
        model.updated_at = Set(Some(now));
    }
}

#[derive(Debug, Validate, Serialize, Deserialize)]
pub struct TransferRequest {
    #[validate(length(min = 1, max = 64))]
    pub from_account: String,

    #[validate(length(min = 1, max = 64))]
    pub to_account: String,

    #[validate(custom(function = "validate_amount"))]
    pub amount: Decimal,

    #[validate(length(min = 1, max = 16))]
    pub currency: String,

    #[validate(length(min = 1, max = 1024))]
    pub description: String,

    #[validate(length(max = 1024))]
    pub notes: Option<String>,

    #[validate(length(min = 1, max = 64))]
    pub payment_method: String,

    pub date: Option<String>,
}

#[derive(Serialize)]
pub struct TransactionResponse {
    pub serial_num: String,
    pub transaction_type: String,
    pub transaction_status: String,
    pub date: String,
    pub amount: Decimal,
    pub currency: String,
    pub description: String,
    pub notes: Option<String>,
    pub account_serial_num: String,
    pub category: String,
    pub sub_category: Option<String>,
    pub tags: Option<String>,
    pub split_members: Option<String>,
    pub payment_method: String,
    pub actual_payer_account: String,
    pub related_transaction_serial_num: Option<String>,
    pub is_deleted: i32,
    pub created_at: String,
    pub updated_at: Option<String>,
}

impl From<entity::transactions::Model> for TransactionResponse {
    fn from(model: entity::transactions::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            transaction_type: model.transaction_type,
            transaction_status: model.transaction_status,
            date: model.date,
            amount: model.amount,
            currency: model.currency,
            description: model.description,
            notes: model.notes,
            account_serial_num: model.account_serial_num,
            category: model.category,
            sub_category: model.sub_category,
            tags: model.tags,
            split_members: model.split_members,
            payment_method: model.payment_method,
            actual_payer_account: model.actual_payer_account,
            related_transaction_serial_num: model.related_transaction_serial_num,
            is_deleted: model.is_deleted,
            created_at: model.created_at,
            updated_at: model.updated_at,
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
fn validate_date(date: &str) -> Result<(), validator::ValidationError> {
    NaiveDate::parse_from_str(date, "%Y-%m-%d")
        .map(|_| ())
        .map_err(|_| validator::ValidationError::new("invalid_date_format"))
}
