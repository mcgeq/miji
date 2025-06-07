// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           account.rs
// Description:    About Account Handler
// Create   Date:  2025-06-07 14:37:22
// Last Modified:  2025-06-07 16:18:27
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{AppState, error::MijiResult};
use tauri::State;

use crate::{
    dto::{AccountDto, AccountResDto},
    services::account::AccountService,
};

pub struct AccountHandler;

impl AccountHandler {
    pub async fn create(
        account_dto: AccountDto,
        state: State<'_, AppState>,
    ) -> MijiResult<AccountResDto> {
        let db = &*state.db;
        AccountService::create(account_dto, db)
            .await
            .map(AccountResDto::from)
    }

    pub async fn update(
        serial_num: &str,
        account_dto: AccountDto,
        state: State<'_, AppState>,
    ) -> MijiResult<AccountResDto> {
        let db = &*state.db;
        AccountService::update(serial_num, account_dto, db)
            .await
            .map(AccountResDto::from)
    }

    pub async fn delete(serial_num: &str, state: State<'_, AppState>) -> MijiResult<AccountResDto> {
        let db = &*state.db;
        AccountService::delete(serial_num, db)
            .await
            .map(AccountResDto::from)
    }
}
