// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           family_ledger_account.rs
// Description:    家庭账本账户关联服务
// Create   Date:  2025-11-15
// Last Modified:  2025-11-15
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use common::error::AppError;
use entity::{family_ledger_account, prelude::*};
use sea_orm::{ColumnTrait, DatabaseConnection, EntityTrait, PaginatorTrait, QueryFilter, Set};

#[derive(Default)]
pub struct FamilyLedgerAccountService;

impl FamilyLedgerAccountService {
    /// 获取所有账本账户关联
    pub async fn list(&self, db: &DatabaseConnection) -> Result<Vec<family_ledger_account::Model>, AppError> {
        FamilyLedgerAccount::find()
            .all(db)
            .await
            .map_err(AppError::from)
    }

    /// 根据账本ID获取账户关联
    pub async fn list_by_ledger(
        &self,
        db: &DatabaseConnection,
        ledger_serial_num: &str,
    ) -> Result<Vec<family_ledger_account::Model>, AppError> {
        FamilyLedgerAccount::find()
            .filter(family_ledger_account::Column::FamilyLedgerSerialNum.eq(ledger_serial_num))
            .all(db)
            .await
            .map_err(AppError::from)
    }

    /// 根据账户ID获取账本关联
    pub async fn list_by_account(
        &self,
        db: &DatabaseConnection,
        account_serial_num: &str,
    ) -> Result<Vec<family_ledger_account::Model>, AppError> {
        FamilyLedgerAccount::find()
            .filter(family_ledger_account::Column::AccountSerialNum.eq(account_serial_num))
            .all(db)
            .await
            .map_err(AppError::from)
    }

    /// 创建账本账户关联
    pub async fn create(
        &self,
        db: &DatabaseConnection,
        ledger_serial_num: String,
        account_serial_num: String,
    ) -> Result<family_ledger_account::Model, AppError> {
        // 检查是否已存在
        let existing = FamilyLedgerAccount::find()
            .filter(family_ledger_account::Column::FamilyLedgerSerialNum.eq(&ledger_serial_num))
            .filter(family_ledger_account::Column::AccountSerialNum.eq(&account_serial_num))
            .one(db)
            .await
            .map_err(AppError::from)?;

        // 如果关联已存在，直接返回现有记录（幂等操作）
        if let Some(existing_model) = existing {
            return Ok(existing_model);
        }

        let now = common::utils::date::DateUtils::local_now();
        let serial_num = common::utils::uuid::McgUuid::uuid(38);
        
        let active_model = family_ledger_account::ActiveModel {
            serial_num: Set(serial_num),
            family_ledger_serial_num: Set(ledger_serial_num.clone()),
            account_serial_num: Set(account_serial_num),
            created_at: Set(now),
            updated_at: Set(None),
        };

        let result = FamilyLedgerAccount::insert(active_model)
            .exec_with_returning(db)
            .await
            .map_err(AppError::from)?;

        // 更新账本的账户数量
        self.update_ledger_account_count(db, &ledger_serial_num).await?;

        Ok(result)
    }
    
    /// 更新账本的账户数量
    async fn update_ledger_account_count(
        &self,
        db: &DatabaseConnection,
        ledger_serial_num: &str,
    ) -> Result<(), AppError> {
        use sea_orm::QueryFilter;
        use entity::prelude::*;
        
        // 查询账户数量
        let count = FamilyLedgerAccount::find()
            .filter(entity::family_ledger_account::Column::FamilyLedgerSerialNum.eq(ledger_serial_num))
            .count(db)
            .await
            .map_err(AppError::from)?;
        
        // 更新账本
        FamilyLedger::update_many()
            .col_expr(
                entity::family_ledger::Column::Accounts,
                sea_orm::sea_query::Expr::value(count as i32),
            )
            .filter(entity::family_ledger::Column::SerialNum.eq(ledger_serial_num))
            .exec(db)
            .await
            .map_err(AppError::from)?;
        
        Ok(())
    }

    /// 删除账本账户关联
    pub async fn delete(
        &self,
        db: &DatabaseConnection,
        ledger_serial_num: &str,
        account_serial_num: &str,
    ) -> Result<(), AppError> {
        FamilyLedgerAccount::delete_many()
            .filter(family_ledger_account::Column::FamilyLedgerSerialNum.eq(ledger_serial_num))
            .filter(family_ledger_account::Column::AccountSerialNum.eq(account_serial_num))
            .exec(db)
            .await
            .map_err(AppError::from)?;

        // 更新账本的账户数量
        self.update_ledger_account_count(db, ledger_serial_num).await?;

        Ok(())
    }

    /// 删除账本的所有账户关联
    pub async fn delete_by_ledger(
        &self,
        db: &DatabaseConnection,
        ledger_serial_num: &str,
    ) -> Result<(), AppError> {
        FamilyLedgerAccount::delete_many()
            .filter(family_ledger_account::Column::FamilyLedgerSerialNum.eq(ledger_serial_num))
            .exec(db)
            .await
            .map_err(AppError::from)?;

        Ok(())
    }

    /// 删除账户的所有账本关联
    pub async fn delete_by_account(
        &self,
        db: &DatabaseConnection,
        account_serial_num: &str,
    ) -> Result<(), AppError> {
        FamilyLedgerAccount::delete_many()
            .filter(family_ledger_account::Column::AccountSerialNum.eq(account_serial_num))
            .exec(db)
            .await
            .map_err(AppError::from)?;

        Ok(())
    }
}
