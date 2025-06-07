// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           transaction.rs
// Description:    About Transaction Handler
// Create   Date:  2025-06-07 14:40:27
// Last Modified:  2025-06-07 23:06:10
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::{AppState, error::MijiResult};
use tauri::State;

use crate::{
    dto::{PageResDto, PaginationParams, TransactionDto, TransactionResDto},
    services::transaction::TransactionService,
};

pub struct TransactionHandler;

impl TransactionHandler {
    pub async fn list(
        account_serial_num: &str,
        pagination_params: &PaginationParams,
        state: State<'_, AppState>,
    ) -> MijiResult<PageResDto<TransactionResDto>> {
        let db = &*state.db;
        let page = pagination_params.page();
        let page_size = pagination_params.page_size();
        let res = TransactionService::list(account_serial_num, pagination_params, db).await?;
        let total = res.len() as u64;
        let data = res
            .into_iter()
            .map(TransactionResDto::from)
            .collect::<Vec<_>>();
        Ok(PageResDto {
            data,
            total,
            page,
            page_size,
        })
    }

    pub async fn create(
        transaction_dto: TransactionDto,
        state: State<'_, AppState>,
    ) -> MijiResult<TransactionResDto> {
        let db = &*state.db;
        TransactionService::create(transaction_dto, db)
            .await
            .map(TransactionResDto::from)
    }

    pub async fn update(
        serial_num: &str,
        account_serial_num: &str,
        transaction_dto: TransactionDto,
        state: State<'_, AppState>,
    ) -> MijiResult<TransactionResDto> {
        let db = &*state.db;
        TransactionService::update(serial_num, account_serial_num, transaction_dto, db)
            .await
            .map(TransactionResDto::from)
    }

    pub async fn delete(
        serial_num: &str,
        account_serial_num: &str,
        state: State<'_, AppState>,
    ) -> MijiResult<TransactionResDto> {
        let db = &*state.db;
        TransactionService::delete(serial_num, account_serial_num, db)
            .await
            .map(TransactionResDto::from)
    }
}
