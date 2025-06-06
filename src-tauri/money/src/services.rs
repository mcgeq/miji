// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           services.rs
// Description:    About Money Services
// Create   Date:  2025-06-06 13:20:14
// Last Modified:  2025-06-06 23:19:43
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::entity::account;
use common::error::MijiError;
use common::sql_error::{SQLError, not_found_error};
use common::utils::date::DateUtils;
use common::{AppState, entity::transaction, error::MijiResult, utils::uuid::McgUuid};
use tauri::State;

use crate::dto::{
    AccountCore, AccountDto, AccountResDto, TransactionCore, TransactionDto, TransactionResDto,
};

use sea_orm::prelude::Decimal;
use sea_orm::{ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, Set};
pub struct MoneyService;

impl MoneyService {
    /// 创建新交易并返回其详细信息。
    ///
    /// # 参数
    /// - `state`: 应用程序状态，包含数据库连接。
    /// - `transaction_dto`: 交易数据传输对象，包含交易详情。
    ///
    /// # 返回
    /// 返回创建的交易的 `TransactionResDto` 或错误。
    pub async fn create_transaction(
        state: State<'_, AppState>,
        transaction_dto: TransactionDto,
    ) -> MijiResult<TransactionResDto> {
        let db = &*state.db;
        let transaction = transaction::ActiveModel {
            serial_num: Set(McgUuid::uuid(32)),
            transaction_type: Set(transaction_dto.core.transaction_type),
            transaction_status: Set(transaction_dto.core.transaction_status),
            date: Set(transaction_dto.core.date),
            amount: Set(transaction_dto.core.amount),
            currency: Set(transaction_dto.core.currency),
            description: Set(transaction_dto.core.description),
            notes: Set(transaction_dto.core.notes),
            account_serial_num: Set(transaction_dto.core.account_serial_num),
            category: Set(transaction_dto.core.category),
            sub_category: Set(transaction_dto.core.sub_category),
            tags: Set(transaction_dto.core.tags),
            split_members: Set(transaction_dto.core.split_members),
            payment_method: Set(transaction_dto.core.payment_method),
            actual_payer_account: Set(transaction_dto.core.actual_payer_account),
            ..Default::default()
        };
        let inserted = transaction.insert(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        let res_dto = TransactionResDto {
            serial_num: inserted.serial_num,
            core: TransactionCore {
                transaction_type: inserted.transaction_type,
                transaction_status: inserted.transaction_status,
                date: inserted.date,
                amount: inserted.amount,
                currency: inserted.currency,
                description: inserted.description,
                notes: inserted.notes,
                account_serial_num: inserted.account_serial_num,
                category: inserted.category,
                sub_category: inserted.sub_category,
                tags: inserted.tags,
                split_members: inserted.split_members,
                payment_method: inserted.payment_method,
                actual_payer_account: inserted.actual_payer_account,
            },
            created_at: inserted.create_at,
            updated_at: Some(inserted.update_at),
        };

        Ok(res_dto)
    }

    /// 更新现有交易并返回其更新后的详细信息。
    ///
    /// # 参数
    /// - `state`: 应用程序状态，包含数据库连接。
    /// - `serial_num`: 要更新的交易的序列号。
    /// - `transaction_dto`: 包含更新数据的交易 DTO。
    ///
    /// # 返回
    /// 返回更新后的交易的 `TransactionResDto` 或错误。
    pub async fn update_transaction(
        state: State<'_, AppState>,
        serial_num: &str,
        transaction_dto: TransactionDto,
    ) -> MijiResult<TransactionResDto> {
        let db = &*state.db;
        let transaction = transaction::Entity::find()
            .filter(transaction::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;
        let mut active_model: transaction::ActiveModel = transaction.into();
        active_model.transaction_type = Set(transaction_dto.core.transaction_type);
        active_model.transaction_status = Set(transaction_dto.core.transaction_status);
        active_model.date = Set(transaction_dto.core.date);
        active_model.amount = Set(transaction_dto.core.amount);
        active_model.currency = Set(transaction_dto.core.currency);
        active_model.description = Set(transaction_dto.core.description);
        active_model.notes = Set(transaction_dto.core.notes);
        active_model.account_serial_num = Set(transaction_dto.core.account_serial_num);
        active_model.category = Set(transaction_dto.core.category);
        active_model.sub_category = Set(transaction_dto.core.sub_category);
        active_model.tags = Set(transaction_dto.core.tags);
        active_model.split_members = Set(transaction_dto.core.split_members);
        active_model.payment_method = Set(transaction_dto.core.payment_method);
        active_model.actual_payer_account = Set(transaction_dto.core.actual_payer_account);
        let updated = active_model.update(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        let res_dto = TransactionResDto {
            serial_num: updated.serial_num,
            core: TransactionCore {
                transaction_type: updated.transaction_type,
                transaction_status: updated.transaction_status,
                date: updated.date,
                amount: updated.amount,
                currency: updated.currency,
                description: updated.description,
                notes: updated.notes,
                account_serial_num: updated.account_serial_num,
                category: updated.category,
                sub_category: updated.sub_category,
                tags: updated.tags,
                split_members: updated.split_members,
                payment_method: updated.payment_method,
                actual_payer_account: updated.actual_payer_account,
            },
            created_at: updated.create_at,
            updated_at: Some(updated.update_at),
        };
        Ok(res_dto)
    }

    /// 根据序列号删除交易。
    ///
    /// # 参数
    /// - `state`: 应用程序状态，包含数据库连接。
    /// - `serial_num`: 要删除的交易的序列号。
    ///
    /// # 返回
    /// 删除成功返回 `Ok(())`，否则返回错误。
    pub async fn delete_transaction(
        state: State<'_, AppState>,
        serial_num: &str,
    ) -> MijiResult<()> {
        let db = &*state.db;
        let _transaction = transaction::Entity::find()
            .filter(transaction::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;
        transaction::Entity::delete_by_id(serial_num)
            .exec(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;
        Ok(())
    }

    /// 创建新账户并返回其详细信息。
    ///
    /// # 参数
    /// - `state`: 应用程序状态，包含数据库连接。
    /// - `account_dto`: 账户数据传输对象，包含账户详情。
    ///
    /// # 返回
    /// 返回创建的账户的 `AccountResDto` 或错误。
    pub async fn create_account(
        state: State<'_, AppState>,
        account_dto: AccountDto,
    ) -> MijiResult<AccountResDto> {
        let db = &*state.db;
        let account = account::ActiveModel {
            serial_num: Set(McgUuid::uuid(32)),
            name: Set(account_dto.core.name),
            description: Set(account_dto.core.description),
            is_shared: Set(account_dto.core.is_shared),
            balance: Set(Decimal::new(0, 2)),
            currency: Set("USD".to_string()),
            owner_id: Set("default_owner".to_string()),
            created_at: Set(DateUtils::current_datetime_local_fixed()),
            ..Default::default()
        };
        let inserted = account.insert(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        let res_dto = AccountResDto {
            serial_num: inserted.serial_num,
            core: AccountCore {
                name: inserted.name,
                description: inserted.description,
                is_shared: inserted.is_shared,
                balance: inserted.balance,
                currency: inserted.currency,
            },
            create_at: inserted.created_at.naive_local(),
            update_at: Some(inserted.updated_at.unwrap().naive_local()),
        };

        Ok(res_dto)
    }

    /// 更新现有账户并返回其更新后的详细信息。
    ///
    /// # 参数
    /// - `state`: 应用程序状态，包含数据库连接。
    /// - `serial_num`: 要更新的账户的序列号。
    /// - `account_dto`: 包含更新数据的账户 DTO。
    ///
    /// # 返回
    /// 返回更新后的账户的 `AccountResDto` 或错误。
    pub async fn update_account(
        state: State<'_, AppState>,
        serial_num: &str,
        account_dto: AccountDto,
    ) -> MijiResult<AccountResDto> {
        let db = &*state.db;
        let account = account::Entity::find()
            .filter(account::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;
        let mut active_model: account::ActiveModel = account.into();
        active_model.name = Set(account_dto.core.name);
        active_model.description = Set(account_dto.core.description);
        active_model.is_shared = Set(account_dto.core.is_shared);
        active_model.updated_at = Set(Some(DateUtils::current_datetime_local_fixed()));
        let updated = active_model.update(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        let res_dto = AccountResDto {
            serial_num: updated.serial_num,
            core: AccountCore {
                name: updated.name,
                description: updated.description,
                is_shared: updated.is_shared,
                balance: updated.balance,
                currency: updated.currency,
            },
            create_at: updated.created_at.naive_local(),
            update_at: Some(updated.updated_at.unwrap().naive_local()),
        };
        Ok(res_dto)
    }
}
