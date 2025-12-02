// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           family_ledger_account.rs
// Description:    家庭账本账户关联 DTO
// Create   Date:  2025-11-15
// Last Modified:  2025-11-15
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use entity::family_ledger_account;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerAccountResponse {
    pub serial_num: String,
    pub family_ledger_serial_num: String,
    pub account_serial_num: String,
    pub created_at: String,
    pub updated_at: Option<String>,
}

impl From<family_ledger_account::Model> for FamilyLedgerAccountResponse {
    fn from(model: family_ledger_account::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            family_ledger_serial_num: model.family_ledger_serial_num,
            account_serial_num: model.account_serial_num,
            created_at: model.created_at.to_rfc3339(),
            updated_at: model.updated_at.map(|dt| dt.to_rfc3339()),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerAccountCreate {
    pub family_ledger_serial_num: String,
    pub account_serial_num: String,
}
