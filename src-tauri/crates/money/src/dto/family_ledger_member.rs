// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           family_ledger_member.rs
// Description:    家庭账本成员关联 DTO
// Create   Date:  2025-11-15
// Last Modified:  2025-11-15
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use entity::family_ledger_member;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerMemberResponse {
    pub family_ledger_serial_num: String,
    pub family_member_serial_num: String,
    pub created_at: String,
    pub updated_at: Option<String>,
}

impl From<family_ledger_member::Model> for FamilyLedgerMemberResponse {
    fn from(model: family_ledger_member::Model) -> Self {
        Self {
            family_ledger_serial_num: model.family_ledger_serial_num,
            family_member_serial_num: model.family_member_serial_num,
            created_at: model.created_at.to_rfc3339(),
            updated_at: model.updated_at.map(|dt| dt.to_rfc3339()),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerMemberCreate {
    pub family_ledger_serial_num: String,
    pub family_member_serial_num: String,
}
