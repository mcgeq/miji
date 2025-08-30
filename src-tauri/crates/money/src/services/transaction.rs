use std::{str::FromStr, sync::Arc};

use common::{
    BusinessCode,
    crud::service::{CrudConverter, CrudService, GenericCrudService, parse_json_field},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::{date::DateUtils, uuid::McgUuid},
};
use sea_orm::{
    ActiveModelTrait,
    ActiveValue::Set,
    ColumnTrait, Condition, DatabaseConnection, DatabaseTransaction, EntityTrait, IntoActiveModel,
    QuerySelect, TransactionTrait,
    prelude::{Decimal, async_trait::async_trait},
};
use serde::{Deserialize, Serialize};
use snafu::GenerateImplicitData;
use validator::Validate;

use crate::{
    dto::{
        account::AccountType,
        transactions::{
            CreateTransactionRequest, PaymentMethod, TransactionStatus, TransactionType,
            TransferRequest, UpdateTransactionRequest,
        },
    },
    error::MoneyError,
    services::transaction_hooks::NoOpHooks,
};

// 交易服务实现
pub struct TransactionService {
    inner: GenericCrudService<
        entity::transactions::Entity,
        TransactionFilter,
        CreateTransactionRequest,
        UpdateTransactionRequest,
        TransactionConverter,
        NoOpHooks,
    >,
}

impl TransactionService {
    pub fn new(
        converter: TransactionConverter,
        hooks: NoOpHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }

    async fn fetch_account(
        &self,
        tx: &DatabaseTransaction,
        account_id: &str,
    ) -> MijiResult<entity::account::Model> {
        entity::account::Entity::find_by_id(account_id)
            .lock_exclusive()
            .one(tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Account not found"))
    }

    async fn update_account_balance(
        &self,
        tx: &DatabaseTransaction,
        account: entity::account::Model,
        new_balance: Decimal,
        operation_type: &str,
    ) -> MijiResult<entity::account::Model> {
        let original_account = account.clone();
        let mut account_active = account.into_active_model();
        account_active.balance = Set(new_balance);
        let updated_account = account_active.update(tx).await?;
        self.account_update_log(tx, &updated_account, &original_account, operation_type)
            .await?;
        Ok(updated_account)
    }

    pub async fn transfer(
        &self,
        db: &DatabaseConnection,
        data: TransferRequest,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        data.validate().map_err(AppError::from_validation_errors)?;
        let tx = db.begin().await?;

        let from_account = self.fetch_account(&tx, &data.from_account).await?;
        let to_account = self.fetch_account(&tx, &data.to_account).await?;

        let amount = data.amount;
        if from_account.balance < amount {
            return Err(MoneyError::InsufficientFunds {
                balance: amount,
                backtrace: snafu::Backtrace::generate(),
            }
            .into());
        }

        let new_from_balance = from_account.balance - amount;
        let new_to_balance = to_account.balance + amount;

        let _updated_from_account = self
            .update_account_balance(
                &tx,
                from_account.clone(),
                new_from_balance,
                "BALANCE_UPDATE_FROM",
            )
            .await?;
        let _updated_to_account = self
            .update_account_balance(&tx, to_account.clone(), new_to_balance, "BALANCE_UPDATE_TO")
            .await?;

        let from_request = CreateTransactionRequest {
            transaction_type: TransactionType::Expense,
            transaction_status: TransactionStatus::Completed,
            date: data.date.clone().unwrap_or_else(DateUtils::local_rfc3339),
            amount: -data.amount,
            currency: data.currency.clone(),
            description: data.description.clone(),
            notes: data.notes.clone(),
            account_serial_num: data.from_account.clone(),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: data.payment_method.clone(),
            actual_payer_account: AccountType::from_str(&from_account.r#type)?,
            related_transaction_serial_num: None,
        };

        let converter = TransactionConverter;
        let from_model = converter
            .create_to_active_model(from_request)?
            .insert(&tx)
            .await?;

        let to_request = CreateTransactionRequest {
            transaction_type: TransactionType::Income,
            transaction_status: TransactionStatus::Completed,
            date: data.date.clone().unwrap_or_else(DateUtils::local_rfc3339),
            amount: data.amount,
            currency: data.currency.clone(),
            description: data.description.clone(),
            notes: data.notes.clone(),
            account_serial_num: data.to_account.clone(),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: data.payment_method.clone(),
            actual_payer_account: AccountType::from_str(&to_account.r#type)?, // Adjust based on context or derive from from_account
            related_transaction_serial_num: Some(from_model.serial_num.clone()),
        };

        let to_model = converter
            .create_to_active_model(to_request)?
            .insert(&tx)
            .await?;

        self.transaction_operation_log(&tx, &from_model, None, "TRANSFER_OUT")
            .await?;
        self.transaction_operation_log(&tx, &to_model, None, "TRANSFER_IN")
            .await?;

        tx.commit().await?;
        Ok((from_model, to_model))
    }

    pub async fn transfer_delete(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        let tx = db.begin().await?;

        let original_outgoing = entity::transactions::Entity::find_by_id(transaction_id)
            .lock_exclusive()
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Transaction not found"))?;

        if original_outgoing.category != "Transfer" {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                "Only transfer transactions can be reversed",
            ));
        }

        let related_id = original_outgoing
            .related_transaction_serial_num
            .as_ref()
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    "Transfer transaction missing related transaction",
                )
            })?
            .clone();

        let original_incoming = entity::transactions::Entity::find_by_id(&related_id)
            .lock_exclusive()
            .one(&tx)
            .await?
            .ok_or_else(|| {
                AppError::simple(BusinessCode::NotFound, "Related transaction not found")
            })?;

        if original_incoming.related_transaction_serial_num.as_deref() != Some(transaction_id) {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                "Transactions are not properly related",
            ));
        }

        let from_account = self
            .fetch_account(&tx, &original_outgoing.account_serial_num)
            .await?;
        let to_account = self
            .fetch_account(&tx, &original_incoming.account_serial_num)
            .await?;

        let amount = original_outgoing.amount.abs();
        let new_from_balance = from_account.balance + amount;
        let new_to_balance = to_account.balance - amount;

        let _updated_from_account = self
            .update_account_balance(&tx, from_account, new_from_balance, "BALANCE_REVERSE_FROM")
            .await?;
        let _updated_to_account = self
            .update_account_balance(&tx, to_account, new_to_balance, "BALANCE_REVERSE_TO")
            .await?;

        let mut original_outgoing_active = original_outgoing.clone().into_active_model();
        original_outgoing_active.is_deleted = Set(1);
        let updated_outgoing = original_outgoing_active.update(&tx).await?;

        let mut original_incoming_active = original_incoming.clone().into_active_model();
        original_incoming_active.is_deleted = Set(1);
        let updated_incoming = original_incoming_active.update(&tx).await?;

        self.transaction_operation_log(
            &tx,
            &updated_outgoing,
            Some(self.serialize_model(&original_outgoing)?),
            "TRANSFER_REVERSE_OUT",
        )
        .await?;
        self.transaction_operation_log(
            &tx,
            &updated_incoming,
            Some(self.serialize_model(&original_incoming)?),
            "TRANSFER_REVERSE_IN",
        )
        .await?;

        let reverse_out_serial_num = McgUuid::uuid(38);
        let reverse_in_serial_num = McgUuid::uuid(38);
        let date = DateUtils::local_rfc3339();
        let reverse_out_request = CreateTransactionRequest {
            transaction_type: TransactionType::Expense,
            transaction_status: TransactionStatus::Reversed,
            date: date.clone(),
            amount: -amount,
            currency: original_outgoing.currency.clone(),
            description: format!("Reversal of {}", original_outgoing.description),
            notes: original_outgoing.notes.clone(),
            account_serial_num: original_incoming.account_serial_num.clone(),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: parse_json_field(
                &original_outgoing.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_json_field(
                &original_outgoing.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: Some(reverse_in_serial_num.clone()),
        };

        let reverse_in_request = CreateTransactionRequest {
            transaction_type: TransactionType::Income,
            transaction_status: TransactionStatus::Reversed,
            date,
            amount,
            currency: original_outgoing.currency.clone(),
            description: format!("Reversal of {}", original_incoming.description),
            notes: original_incoming.notes.clone(),
            account_serial_num: original_outgoing.account_serial_num.clone(),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: parse_json_field(
                &original_outgoing.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_json_field(
                &original_outgoing.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: Some(reverse_out_serial_num.clone()),
        };

        let converter = TransactionConverter;
        let reverse_out_model = converter
            .create_to_active_model(reverse_out_request)?
            .insert(&tx)
            .await?;
        let reverse_in_model = converter
            .create_to_active_model(reverse_in_request)?
            .insert(&tx)
            .await?;

        self.transaction_operation_log(
            &tx,
            &reverse_out_model,
            None,
            "TRANSFER_REVERSE_OUT_CREATE",
        )
        .await?;
        self.transaction_operation_log(&tx, &reverse_in_model, None, "TRANSFER_REVERSE_IN_CREATE")
            .await?;

        tx.commit().await?;
        Ok((reverse_out_model, reverse_in_model))
    }

    // ----- Log
    async fn account_update_log(
        &self,
        tx: &DatabaseTransaction,
        updated_model: &entity::account::Model,
        original_model: &entity::account::Model,
        operation_type: &str,
    ) -> MijiResult<()> {
        let table_name = "accounts";
        let record_id = updated_model.serial_num.clone();
        let data_before = serde_json::to_value(original_model)
            .map_err(|e| AppError::internal_server_error(format!("Serialization failed: {e}")))?;
        let data_after = serde_json::to_value(updated_model)
            .map_err(|e| AppError::internal_server_error(format!("Serialization failed: {e}")))?;

        self.logger()
            .log_operation(
                operation_type,
                table_name,
                &record_id,
                Some(&data_before),
                Some(&data_after),
                Some(tx),
            )
            .await?;
        Ok(())
    }

    async fn transaction_operation_log(
        &self,
        tx: &DatabaseTransaction,
        model: &entity::transactions::Model,
        data_before: Option<serde_json::Value>,
        operation_type: &str,
    ) -> MijiResult<()> {
        let table_name = self.converter().table_name();
        let record_id = model.serial_num.clone();
        let data_after = self.serialize_model(model)?;

        self.logger()
            .log_operation(
                operation_type,
                table_name,
                &record_id,
                data_before.as_ref(),
                Some(&data_after),
                Some(tx),
            )
            .await?;
        Ok(())
    }

    // ================================
    // 辅助函数：统一日志
    // ================================
    async fn log_transfer(
        &self,
        tx: &DatabaseTransaction,
        out_model: &entity::transactions::Model,
        in_model: &entity::transactions::Model,
        out_snapshot: Option<String>,
        in_snapshot: Option<String>,
    ) -> MijiResult<()> {
        self.transaction_operation_log(
            tx,
            out_model,
            out_snapshot.as_ref().map(|s| s.as_str()),
            "TRANSFER_OUT",
        )
        .await?;
        self.transaction_operation_log(
            tx,
            in_model,
            in_snapshot.as_ref().map(|s| s.as_str()),
            "TRANSFER_IN",
        )
        .await?;
        Ok(())
    }

    // ================================
    // 辅助函数：余额更新
    // ================================
    async fn apply_balances(
        &self,
        tx: &DatabaseTransaction,
        from_account: &entity::account::Model,
        to_account: &entity::account::Model,
        amount: Decimal,
    ) -> MijiResult<()> {
        let _ = self
            .update_account_balance(
                tx,
                from_account.clone(),
                from_account.balance - amount,
                "BALANCE_UPDATE_FROM",
            )
            .await?;
        let _ = self
            .update_account_balance(
                tx,
                to_account.clone(),
                to_account.balance + amount,
                "BALANCE_UPDATE_TO",
            )
            .await?;
        Ok(())
    }

    async fn revert_balances(
        &self,
        tx: &DatabaseTransaction,
        outgoing: &entity::transactions::Model,
        incoming: &entity::transactions::Model,
        amount: Decimal,
    ) -> MijiResult<()> {
        let from_account = self.fetch_account(tx, &outgoing.account_serial_num).await?;
        let to_account = self.fetch_account(tx, &incoming.account_serial_num).await?;
        let _ = self
            .update_account_balance(
                tx,
                from_account,
                from_account.balance + amount,
                "BALANCE_REVERSE_FROM",
            )
            .await?;
        let _ = self
            .update_account_balance(
                tx,
                to_account,
                to_account.balance - amount,
                "BALANCE_REVERSE_TO",
            )
            .await?;
        Ok(())
    }

    // ================================
    // 辅助函数：标记交易删除
    // ================================
    async fn mark_transaction_deleted(
        &self,
        tx: &DatabaseTransaction,
        model: entity::transactions::Model,
    ) -> MijiResult<entity::transactions::Model> {
        let mut active = model.into_active_model();
        active.is_deleted = Set(1);
        Ok(active.update(tx).await?)
    }

    // ================================
    // 构造正向转账请求
    // ================================
    fn build_transfer_requests(
        &self,
        data: &TransferRequest,
        from_account: &entity::account::Model,
        to_account: &entity::account::Model,
    ) -> MijiResult<(CreateTransactionRequest, CreateTransactionRequest)> {
        let date = data.date.clone().unwrap_or_else(DateUtils::local_rfc3339);

        let from_request = CreateTransactionRequest {
            transaction_type: TransactionType::Expense,
            transaction_status: TransactionStatus::Completed,
            date: date.clone(),
            amount: -data.amount,
            currency: data.currency.clone(),
            description: data.description.clone(),
            notes: data.notes.clone(),
            account_serial_num: data.from_account.clone(),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: data.payment_method.clone(),
            actual_payer_account: AccountType::from_str(&from_account.r#type)?,
            related_transaction_serial_num: None,
        };

        let to_request = CreateTransactionRequest {
            transaction_type: TransactionType::Income,
            transaction_status: TransactionStatus::Completed,
            date,
            amount: data.amount,
            currency: data.currency.clone(),
            description: data.description.clone(),
            notes: data.notes.clone(),
            account_serial_num: data.to_account.clone(),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: data.payment_method.clone(),
            actual_payer_account: AccountType::from_str(&to_account.r#type)?,
            related_transaction_serial_num: None, // 插入后回填
        };

        Ok((from_request, to_request))
    }

    // ================================
    // 构造 reversal request
    // ================================
    fn build_reversal_requests(
        &self,
        outgoing: &entity::transactions::Model,
        incoming: &entity::transactions::Model,
        amount: Decimal,
    ) -> (CreateTransactionRequest, CreateTransactionRequest) {
        let reverse_out_serial_num = McgUuid::uuid(38);
        let reverse_in_serial_num = McgUuid::uuid(38);
        let date = DateUtils::local_rfc3339();

        let reverse_out_request = CreateTransactionRequest {
            transaction_type: TransactionType::Expense,
            transaction_status: TransactionStatus::Reversed,
            date: date.clone(),
            amount: -amount,
            currency: outgoing.currency.clone(),
            description: format!("Reversal of {}", outgoing.description),
            notes: outgoing.notes.clone(),
            account_serial_num: incoming.account_serial_num.clone(),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: parse_json_field(
                &outgoing.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_json_field(
                &outgoing.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: Some(reverse_in_serial_num.clone()),
        };

        let reverse_in_request = CreateTransactionRequest {
            transaction_type: TransactionType::Income,
            transaction_status: TransactionStatus::Reversed,
            date,
            amount,
            currency: outgoing.currency.clone(),
            description: format!("Reversal of {}", incoming.description),
            notes: incoming.notes.clone(),
            account_serial_num: outgoing.account_serial_num.clone(),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: parse_json_field(
                &outgoing.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_json_field(
                &outgoing.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: Some(reverse_out_serial_num.clone()),
        };

        (reverse_out_request, reverse_in_request)
    }

    // ================================
    // 查找并校验关联转账交易对
    // ================================
    async fn fetch_related_transfer(
        &self,
        tx: &DatabaseTransaction,
        transaction_id: &str,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        let outgoing = entity::transactions::Entity::find_by_id(transaction_id)
            .lock_exclusive()
            .one(tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Transaction not found"))?;

        if outgoing.category != "Transfer" {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                "Only transfer transactions can be reversed",
            ));
        }

        let related_id = outgoing
            .related_transaction_serial_num
            .clone()
            .ok_or_else(|| {
                AppError::simple(BusinessCode::NotFound, "Missing related transaction")
            })?;

        let incoming = entity::transactions::Entity::find_by_id(&related_id)
            .lock_exclusive()
            .one(tx)
            .await?
            .ok_or_else(|| {
                AppError::simple(BusinessCode::NotFound, "Related transaction not found")
            })?;

        if incoming.related_transaction_serial_num.as_deref() != Some(transaction_id) {
            return Err(AppError::simple(
                BusinessCode::NotFound,
                "Transactions are not properly related",
            ));
        }

        Ok((outgoing, incoming))
    }

    fn serialize_model(
        &self,
        model: &entity::transactions::Model,
    ) -> MijiResult<serde_json::Value> {
        serde_json::to_value(model)
            .map_err(|e| AppError::internal_server_error(format!("Serialization failed: {e}")))
    }
}

impl std::ops::Deref for TransactionService {
    type Target = GenericCrudService<
        entity::transactions::Entity,
        TransactionFilter,
        CreateTransactionRequest,
        UpdateTransactionRequest,
        TransactionConverter,
        NoOpHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

// 交易转换器
#[derive(Debug)]
pub struct TransactionConverter;

impl CrudConverter<entity::transactions::Entity, CreateTransactionRequest, UpdateTransactionRequest>
    for TransactionConverter
{
    fn create_to_active_model(
        &self,
        data: CreateTransactionRequest,
    ) -> MijiResult<entity::transactions::ActiveModel> {
        entity::transactions::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::transactions::Model,
        data: UpdateTransactionRequest,
    ) -> MijiResult<entity::transactions::ActiveModel> {
        entity::transactions::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = Set(model.serial_num.clone());
                active_model.created_at = Set(model.created_at.clone());
                active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::transactions::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "transactions"
    }
}

// 交易过滤器
#[derive(Debug, Clone, Validate, Serialize, Deserialize)]
pub struct TransactionFilter {
    pub serial_num: Option<String>,
    pub transaction_type: Option<String>,
    pub transaction_status: Option<String>,
    pub date_start: Option<String>,
    pub date_end: Option<String>,
    pub amount_min: Option<Decimal>,
    pub amount_max: Option<Decimal>,
    pub currency: Option<String>,
    pub account_serial_num: Option<String>,
    pub category: Option<String>,
    pub sub_category: Option<String>,
    pub payment_method: Option<String>,
    pub actual_payer_account: Option<String>,
    pub is_deleted: Option<i32>,
}

impl Filter<entity::transactions::Entity> for TransactionFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();

        if let Some(serial_num) = &self.serial_num {
            condition = condition.add(entity::transactions::Column::SerialNum.eq(serial_num));
        }
        if let Some(transaction_type) = &self.transaction_type {
            condition =
                condition.add(entity::transactions::Column::TransactionType.eq(transaction_type));
        }
        if let Some(transaction_status) = &self.transaction_status {
            condition = condition
                .add(entity::transactions::Column::TransactionStatus.eq(transaction_status));
        }
        if let Some(date_start) = &self.date_start {
            condition = condition.add(entity::transactions::Column::Date.gte(date_start));
        }
        if let Some(date_end) = &self.date_end {
            condition = condition.add(entity::transactions::Column::Date.lte(date_end));
        }
        if let Some(amount_min) = &self.amount_min {
            condition = condition.add(entity::transactions::Column::Amount.gte(*amount_min));
        }
        if let Some(amount_max) = &self.amount_max {
            condition = condition.add(entity::transactions::Column::Amount.lte(*amount_max));
        }
        if let Some(currency) = &self.currency {
            condition = condition.add(entity::transactions::Column::Currency.eq(currency));
        }
        if let Some(account_serial_num) = &self.account_serial_num {
            condition = condition
                .add(entity::transactions::Column::AccountSerialNum.eq(account_serial_num));
        }
        if let Some(category) = &self.category {
            condition = condition.add(entity::transactions::Column::Category.eq(category));
        }
        if let Some(sub_category) = &self.sub_category {
            condition = condition.add(entity::transactions::Column::SubCategory.eq(sub_category));
        }
        if let Some(payment_method) = &self.payment_method {
            condition =
                condition.add(entity::transactions::Column::PaymentMethod.eq(payment_method));
        }
        if let Some(actual_payer_account) = &self.actual_payer_account {
            condition = condition
                .add(entity::transactions::Column::ActualPayerAccount.eq(actual_payer_account));
        }
        if let Some(is_deleted) = self.is_deleted {
            condition = condition.add(entity::transactions::Column::IsDeleted.eq(is_deleted));
        }

        condition
    }
}

#[async_trait]
impl
    CrudService<
        entity::transactions::Entity,
        TransactionFilter,
        CreateTransactionRequest,
        UpdateTransactionRequest,
    > for TransactionService
{
    async fn create(
        &self,
        db: &DatabaseConnection,
        data: CreateTransactionRequest,
    ) -> MijiResult<entity::transactions::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<entity::transactions::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DatabaseConnection,
        id: String,
        data: UpdateTransactionRequest,
    ) -> MijiResult<entity::transactions::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DatabaseConnection, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DatabaseConnection) -> MijiResult<Vec<entity::transactions::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        filter: TransactionFilter,
    ) -> MijiResult<Vec<entity::transactions::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<TransactionFilter>,
    ) -> MijiResult<PagedResult<entity::transactions::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DatabaseConnection,
        data: Vec<CreateTransactionRequest>,
    ) -> MijiResult<Vec<entity::transactions::Model>> {
        self.inner.create_batch(db, data).await
    }

    async fn delete_batch(&self, db: &DatabaseConnection, ids: Vec<String>) -> MijiResult<u64> {
        self.inner.delete_batch(db, ids).await
    }

    async fn exists(&self, db: &DatabaseConnection, id: String) -> MijiResult<bool> {
        self.inner.exists(db, id).await
    }

    async fn count(&self, db: &DatabaseConnection) -> MijiResult<u64> {
        self.inner.count(db).await
    }

    async fn count_with_filter(
        &self,
        db: &DatabaseConnection,
        filter: TransactionFilter,
    ) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

// 获取交易服务实例
pub fn get_transaction_service() -> TransactionService {
    TransactionService::new(
        TransactionConverter,
        NoOpHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
