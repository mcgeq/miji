use common::{
    business_code::BusinessCode,
    error::{AppError, MijiResult},
    paginations::{PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::{
    family_ledger_transaction,
    prelude::{FamilyLedger, Transactions},
};
use sea_orm::{
    ActiveModelTrait,
    ActiveValue::Set,
    Condition,
    ColumnTrait,
    DatabaseConnection,
    EntityTrait,
    PaginatorTrait,
    QueryFilter,
    QueryOrder,
    QuerySelect,
};
use validator::Validate;

use crate::dto::family_ledger_transaction::{
    FamilyLedgerTransactionCreate,
    FamilyLedgerTransactionFilter,
    FamilyLedgerTransactionUpdate,
};

#[derive(Debug)]
pub struct FamilyLedgerTransactionService;

impl FamilyLedgerTransactionService {
    pub fn new() -> Self {
        Self
    }

    pub async fn list_associations(
        &self,
        db: &DatabaseConnection,
        filter: Option<FamilyLedgerTransactionFilter>,
    ) -> MijiResult<Vec<family_ledger_transaction::Model>> {
        let condition = filter
            .unwrap_or_default()
            .into_condition();

        family_ledger_transaction::Entity::find()
            .filter(condition)
            .order_by_desc(family_ledger_transaction::Column::UpdatedAt)
            .all(db)
            .await
            .map_err(AppError::from)
    }

    pub async fn create_association(
        &self,
        db: &DatabaseConnection,
        data: FamilyLedgerTransactionCreate,
    ) -> MijiResult<family_ledger_transaction::Model> {
        data.validate()
            .map_err(AppError::from_validation_errors)?;

        self.ensure_family_ledger_exists(db, &data.family_ledger_serial_num)
            .await?;
        self.ensure_transaction_exists(db, &data.transaction_serial_num)
            .await?;
        self.ensure_association_unique(
            db,
            &data.family_ledger_serial_num,
            &data.transaction_serial_num,
        )
        .await?;

        let model = family_ledger_transaction::ActiveModel {
            family_ledger_serial_num: Set(data.family_ledger_serial_num.clone()),
            transaction_serial_num: Set(data.transaction_serial_num.clone()),
            created_at: Set(DateUtils::local_now()),
            updated_at: Set(None),
        };

        model.insert(db).await.map_err(AppError::from)
    }

    pub async fn get_association_by_serial(
        &self,
        db: &DatabaseConnection,
        serial_num: &str,
    ) -> MijiResult<Option<family_ledger_transaction::Model>> {
        let (ledger_serial, transaction_serial) = Self::parse_serial(serial_num)?;
        self.find_one(db, &ledger_serial, &transaction_serial).await
    }

    pub async fn update_association(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        data: FamilyLedgerTransactionUpdate,
    ) -> MijiResult<family_ledger_transaction::Model> {
        data.validate()
            .map_err(AppError::from_validation_errors)?;

        let (ledger_serial, transaction_serial) = Self::parse_serial(&serial_num)?;
        let existing = self
            .find_one(db, &ledger_serial, &transaction_serial)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "关联不存在"))?;

        let new_ledger = data
            .family_ledger_serial_num
            .unwrap_or(ledger_serial);
        let new_transaction = data
            .transaction_serial_num
            .unwrap_or(transaction_serial);

        if new_ledger != existing.family_ledger_serial_num {
            self.ensure_family_ledger_exists(db, &new_ledger).await?;
        }
        if new_transaction != existing.transaction_serial_num {
            self.ensure_transaction_exists(db, &new_transaction).await?;
        }

        if new_ledger != existing.family_ledger_serial_num
            || new_transaction != existing.transaction_serial_num
        {
            self.ensure_association_unique(db, &new_ledger, &new_transaction)
                .await?;
        }

        let mut active: family_ledger_transaction::ActiveModel = existing.into();
        active.family_ledger_serial_num = Set(new_ledger);
        active.transaction_serial_num = Set(new_transaction);
        active.updated_at = Set(Some(DateUtils::local_now()));

        active.update(db).await.map_err(AppError::from)
    }

    pub async fn delete_association(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<()> {
        let (ledger_serial, transaction_serial) = Self::parse_serial(&serial_num)?;
        let result = family_ledger_transaction::Entity::delete_many()
            .filter(family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(ledger_serial))
            .filter(family_ledger_transaction::Column::TransactionSerialNum.eq(transaction_serial))
            .exec(db)
            .await
            .map_err(AppError::from)?;

        if result.rows_affected == 0 {
            return Err(AppError::simple(BusinessCode::NotFound, "关联不存在"));
        }
        Ok(())
    }

    pub async fn list_associations_paged(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<FamilyLedgerTransactionFilter>,
    ) -> MijiResult<PagedResult<family_ledger_transaction::Model>> {
        query
            .validate()
            .map_err(AppError::from_validation_errors)?;

        let condition = query.filter.clone().into_condition();
        let base_query = family_ledger_transaction::Entity::find().filter(condition);

        let total_count = base_query.clone().count(db).await.map_err(AppError::from)? as usize;
        let total_pages = (total_count + query.page_size - 1) / query.page_size;
        let offset = (query.current_page.saturating_sub(1) * query.page_size) as u64;

        let rows = base_query
            .order_by_desc(family_ledger_transaction::Column::UpdatedAt)
            .offset(offset)
            .limit(query.page_size as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;

        Ok(PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

    async fn ensure_family_ledger_exists(
        &self,
        db: &DatabaseConnection,
        serial_num: &str,
    ) -> MijiResult<()> {
        let exists = FamilyLedger::find_by_id(serial_num.to_string())
            .one(db)
            .await?
            .is_some();

        if !exists {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                format!("家庭账本不存在: {serial_num}"),
            ));
        }

        Ok(())
    }

    async fn ensure_transaction_exists(
        &self,
        db: &DatabaseConnection,
        serial_num: &str,
    ) -> MijiResult<()> {
        let exists = Transactions::find_by_id(serial_num.to_string())
            .one(db)
            .await?
            .is_some();

        if !exists {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                format!("交易不存在: {serial_num}"),
            ));
        }

        Ok(())
    }

    async fn ensure_association_unique(
        &self,
        db: &DatabaseConnection,
        ledger_serial: &str,
        transaction_serial: &str,
    ) -> MijiResult<()> {
        if self
            .find_one(db, ledger_serial, transaction_serial)
            .await?
            .is_some()
        {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "该交易已关联到当前账本",
            ));
        }
        Ok(())
    }

    async fn find_one(
        &self,
        db: &DatabaseConnection,
        ledger_serial: &str,
        transaction_serial: &str,
    ) -> MijiResult<Option<family_ledger_transaction::Model>> {
        family_ledger_transaction::Entity::find()
            .filter(family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(ledger_serial))
            .filter(family_ledger_transaction::Column::TransactionSerialNum.eq(transaction_serial))
            .one(db)
            .await
            .map_err(AppError::from)
    }

    fn parse_serial(serial_num: &str) -> MijiResult<(String, String)> {
        let mut parts = serial_num.splitn(2, ':');
        let first = parts.next().unwrap_or_default();
        let second = parts.next();

        if first.is_empty() || second.is_none() || second.unwrap().is_empty() {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                format!("无效的关联编号: {serial_num}"),
            ));
        }

        Ok((first.to_string(), second.unwrap().to_string()))
    }
}

impl Default for FamilyLedgerTransactionService {
    fn default() -> Self {
        Self::new()
    }
}

trait LedgerTransactionFilterExt {
    fn into_condition(self) -> Condition;
}

impl LedgerTransactionFilterExt for FamilyLedgerTransactionFilter {
    fn into_condition(self) -> Condition {
        let mut condition = Condition::all();
        if let Some(ledger_serial) = self.family_ledger_serial_num {
            condition = condition.add(
                family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(ledger_serial),
            );
        }
        if let Some(transaction_serial) = self.transaction_serial_num {
            condition = condition.add(
                family_ledger_transaction::Column::TransactionSerialNum.eq(transaction_serial),
            );
        }
        condition
    }
}
