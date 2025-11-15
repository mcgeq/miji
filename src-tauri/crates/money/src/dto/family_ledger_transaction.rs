use chrono::{DateTime, FixedOffset};
use entity::family_ledger_transaction;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerTransactionFilter {
    pub family_ledger_serial_num: Option<String>,
    pub transaction_serial_num: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerTransactionCreate {
    #[validate(length(min = 1))]
    pub family_ledger_serial_num: String,
    #[validate(length(min = 1))]
    pub transaction_serial_num: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerTransactionUpdate {
    #[validate(length(min = 1))]
    pub family_ledger_serial_num: Option<String>,
    #[validate(length(min = 1))]
    pub transaction_serial_num: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerTransactionResponse {
    pub serial_num: String,
    pub family_ledger_serial_num: String,
    pub transaction_serial_num: String,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

impl From<family_ledger_transaction::Model> for FamilyLedgerTransactionResponse {
    fn from(model: family_ledger_transaction::Model) -> Self {
        Self {
            serial_num: format!(
                "{}:{}",
                model.family_ledger_serial_num, model.transaction_serial_num
            ),
            family_ledger_serial_num: model.family_ledger_serial_num,
            transaction_serial_num: model.transaction_serial_num,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}
