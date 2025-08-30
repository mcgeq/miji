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
    ColumnTrait, Condition, DatabaseConnection, DatabaseTransaction, DbConn, EntityTrait,
    IntoActiveModel, QueryFilter, QuerySelect, TransactionTrait,
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
            TransactionWithRelations, TransferRequest, UpdateTransactionRequest,
        },
    },
    error::MoneyError,
    services::{
        account::get_account_service, currency::get_currency_service, transaction_hooks::NoOpHooks,
    },
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
        account: &entity::account::Model,
        new_balance: Decimal,
        operation_type: &str,
    ) -> MijiResult<entity::account::Model> {
        let original_account = account.clone();
        let mut account_active = account.clone().into_active_model();
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

        let from_account = self.fetch_account(&tx, &data.account_serial_num).await?;
        let to_account = self.fetch_account(&tx, &data.to_account_serial_num).await?;

        let amount = data.amount;
        if from_account.balance < amount {
            return Err(MoneyError::InsufficientFunds {
                balance: amount,
                backtrace: snafu::Backtrace::generate(),
            }
            .into());
        }

        self.apply_balances(&tx, &from_account, &to_account, amount)
            .await?;

        let (from_request, mut to_request) =
            self.build_transfer_requests(&data, &from_account, &to_account)?;

        let converter = TransactionConverter;
        let from_model = converter
            .create_to_active_model(from_request)?
            .insert(&tx)
            .await?;
        to_request.related_transaction_serial_num = Some(from_model.serial_num.clone());
        let to_model = converter
            .create_to_active_model(to_request)?
            .insert(&tx)
            .await?;

        self.log_transfer(&tx, &from_model, &to_model, None, None)
            .await?;

        tx.commit().await?;
        Ok((from_model, to_model))
    }

    pub async fn transfer_update(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
        data: TransferRequest,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        // Validate the input data
        data.validate().map_err(AppError::from_validation_errors)?;
        let tx = db.begin().await?;

        // Fetch the original transfer pair
        let (original_outgoing, original_incoming) =
            self.fetch_related_transfer(&tx, transaction_id).await?;

        // Fetch the accounts involved
        let from_account = self.fetch_account(&tx, &data.account_serial_num).await?;
        let to_account = self.fetch_account(&tx, &data.to_account_serial_num).await?;

        // Validate the new amount
        let new_amount = data.amount;
        if new_amount.is_sign_negative() {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Transfer amount must be non-negative",
            ));
        }

        // Calculate the difference in amount
        let original_amount = original_outgoing.amount.abs();

        // Revert original balances
        self.revert_balances(&tx, &original_outgoing, &original_incoming, original_amount)
            .await?;

        // Check if the from_account has sufficient balance for the new amount
        if from_account.balance < new_amount {
            return Err(MoneyError::InsufficientFunds {
                balance: new_amount,
                backtrace: snafu::Backtrace::generate(),
            }
            .into());
        }

        // Apply new balances
        self.apply_balances(&tx, &from_account, &to_account, new_amount)
            .await?;

        // Build updated transaction requests
        let (mut from_request, mut to_request) =
            self.build_transfer_requests(&data, &from_account, &to_account)?;

        // Set the serial numbers to match the original transactions
        from_request.transaction_status = TransactionStatus::Completed; // Ensure status remains Completed
        to_request.transaction_status = TransactionStatus::Completed;
        from_request.related_transaction_serial_num = Some(original_incoming.serial_num.clone());
        to_request.related_transaction_serial_num = Some(original_outgoing.serial_num.clone());

        // Convert to ActiveModel for updates
        let mut from_active_model = entity::transactions::ActiveModel::try_from(from_request)
            .map_err(AppError::from_validation_errors)?;
        from_active_model.serial_num = Set(original_outgoing.serial_num.clone());
        from_active_model.created_at = Set(original_outgoing.created_at.clone());

        let mut to_active_model = entity::transactions::ActiveModel::try_from(to_request)
            .map_err(AppError::from_validation_errors)?;
        to_active_model.serial_num = Set(original_incoming.serial_num.clone());
        to_active_model.created_at = Set(original_incoming.created_at.clone());

        // Update the transactions
        let updated_outgoing = from_active_model.update(&tx).await?;
        let updated_incoming = to_active_model.update(&tx).await?;

        // Log the update operations
        self.transaction_operation_log(
            &tx,
            &updated_outgoing,
            Some(self.serialize_model(&original_outgoing)?),
            "TRANSFER_UPDATE_OUT",
        )
        .await?;
        self.transaction_operation_log(
            &tx,
            &updated_incoming,
            Some(self.serialize_model(&original_incoming)?),
            "TRANSFER_UPDATE_IN",
        )
        .await?;

        tx.commit().await?;
        Ok((updated_outgoing, updated_incoming))
    }

    pub async fn transfer_delete(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        let tx = db.begin().await?;
        let (original_outgoing, original_incoming) =
            self.fetch_related_transfer(&tx, transaction_id).await?;

        let amount = original_outgoing.amount.abs();
        self.revert_balances(&tx, &original_outgoing, &original_incoming, amount)
            .await?;

        let updated_outgoing = self
            .mark_transaction_deleted(&tx, original_outgoing.clone())
            .await?;
        let updated_incoming = self
            .mark_transaction_deleted(&tx, original_incoming.clone())
            .await?;

        // 记录软删除操作日志
        self.transaction_operation_log(
            &tx,
            &updated_outgoing,
            Some(self.serialize_model(&original_outgoing)?),
            "TRANSFER_REVERSE_OUT_MARK_DELETED",
        )
        .await?;
        self.transaction_operation_log(
            &tx,
            &updated_incoming,
            Some(self.serialize_model(&original_incoming)?),
            "TRANSFER_REVERSE_IN_MARK_DELETED",
        )
        .await?;

        let (reverse_out_request, mut reverse_in_request) =
            self.build_reversal_requests(&original_outgoing, &original_incoming, amount);

        let converter = TransactionConverter;
        let reverse_out_model = converter
            .create_to_active_model(reverse_out_request)?
            .insert(&tx)
            .await?;
        reverse_in_request.related_transaction_serial_num =
            Some(reverse_out_model.serial_num.clone());
        let reverse_in_model = converter
            .create_to_active_model(reverse_in_request)?
            .insert(&tx)
            .await?;
        let outgoing_snapshot = self.serialize_model(&original_outgoing)?;
        let incoming_snapshot = self.serialize_model(&original_incoming)?;
        self.log_transfer(
            &tx,
            &reverse_out_model,
            &reverse_in_model,
            Some(outgoing_snapshot.to_string()),
            Some(incoming_snapshot.to_string()),
        )
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
        let out_before: Option<serde_json::Value> = match out_snapshot {
            Some(s) => Some(parse_json(&s, "out_snapshot")?),
            None => None,
        };

        let in_before: Option<serde_json::Value> = match in_snapshot {
            Some(s) => Some(parse_json(&s, "in_snapshot")?),
            None => None,
        };
        self.transaction_operation_log(tx, out_model, out_before, "TRANSFER_OUT")
            .await?;
        self.transaction_operation_log(tx, in_model, in_before, "TRANSFER_IN")
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
                from_account,
                from_account.balance - amount,
                "BALANCE_UPDATE_FROM",
            )
            .await?;
        let _ = self
            .update_account_balance(
                tx,
                to_account,
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
                &from_account,
                from_account.balance + amount,
                "BALANCE_REVERSE_FROM",
            )
            .await?;
        let _ = self
            .update_account_balance(
                tx,
                &to_account,
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
            account_serial_num: data.account_serial_num.clone(),
            category: "Transfer".to_string(),
            notes: Some(data.description.clone()),
            sub_category: data.sub_category.clone(),
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
            notes: Some(data.description.clone()),
            account_serial_num: data.to_account_serial_num.clone(),
            category: "Transfer".to_string(),
            sub_category: data.sub_category.clone(),
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

        let incoming = entity::transactions::Entity::find()
            .filter(entity::transactions::Column::RelatedTransactionSerialNum.eq(related_id))
            .lock_exclusive()
            .one(tx)
            .await?
            .ok_or_else(|| {
                AppError::simple(BusinessCode::NotFound, "Related transaction not found")
            })?;

        if outgoing.transaction_type == "Expense" {
            Ok((outgoing, incoming))
        } else {
            Ok((incoming, outgoing))
        }
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

impl TransactionConverter {
    pub async fn model_to_with_relations(
        &self,
        db: &DbConn,
        model: entity::transactions::Model,
    ) -> MijiResult<TransactionWithRelations> {
        let account_service = get_account_service();
        let cny_service = get_currency_service();

        let (account, currency, family_member) = tokio::try_join!(
            async {
                account_service
                    .get_account_with_relations(db, model.account_serial_num.clone())
                    .await
            },
            async { cny_service.get_by_id(db, model.currency.clone()).await },
            async {
                entity::family_member::Entity::find()
                    .filter(entity::family_member::Column::SerialNum.is_in(&model.split_members))
                    .all(db)
                    .await
                    .map_err(Into::into)
            }
        )?;
        Ok(TransactionWithRelations {
            transaction: model,
            account,
            currency,
            family_member,
        })
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
        db: &DbConn,
        data: CreateTransactionRequest,
    ) -> MijiResult<entity::transactions::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(&self, db: &DbConn, id: String) -> MijiResult<entity::transactions::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        id: String,
        data: UpdateTransactionRequest,
    ) -> MijiResult<entity::transactions::Model> {
        self.inner.update(db, id, data).await
    }

    async fn delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(db, id).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<entity::transactions::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: TransactionFilter,
    ) -> MijiResult<Vec<entity::transactions::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<TransactionFilter>,
    ) -> MijiResult<PagedResult<entity::transactions::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<CreateTransactionRequest>,
    ) -> MijiResult<Vec<entity::transactions::Model>> {
        self.inner.create_batch(db, data).await
    }

    async fn delete_batch(&self, db: &DbConn, ids: Vec<String>) -> MijiResult<u64> {
        self.inner.delete_batch(db, ids).await
    }

    async fn exists(&self, db: &DbConn, id: String) -> MijiResult<bool> {
        self.inner.exists(db, id).await
    }

    async fn count(&self, db: &DbConn) -> MijiResult<u64> {
        self.inner.count(db).await
    }

    async fn count_with_filter(&self, db: &DbConn, filter: TransactionFilter) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

// =======================================
// 新增带关联方法
// =======================================
impl TransactionService {
    pub async fn trans_create_with_relations(
        &self,
        db: &DbConn,
        data: CreateTransactionRequest,
    ) -> MijiResult<TransactionWithRelations> {
        let model = self.create(db, data).await?;
        self.converter().model_to_with_relations(db, model).await
    }

    pub async fn trans_get_with_relations(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<TransactionWithRelations> {
        let model = self.get_by_id(db, id).await?;
        self.converter().model_to_with_relations(db, model).await
    }

    pub async fn trans_update_with_relations(
        &self,
        db: &DbConn,
        id: String,
        data: UpdateTransactionRequest,
    ) -> MijiResult<TransactionWithRelations> {
        let model = self.update(db, id, data).await?;
        self.converter().model_to_with_relations(db, model).await
    }

    pub async fn trans_transfer_create_with_relations(
        &self,
        db: &DbConn,
        data: TransferRequest,
    ) -> MijiResult<(TransactionWithRelations, TransactionWithRelations)> {
        let (from_model, to_model) = self.transfer(db, data).await?;
        let f = self
            .converter()
            .model_to_with_relations(db, from_model)
            .await?;
        let t = self
            .converter()
            .model_to_with_relations(db, to_model)
            .await?;
        Ok((f, t))
    }

    pub async fn trans_transfer_update_with_relations(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
        data: TransferRequest,
    ) -> MijiResult<(TransactionWithRelations, TransactionWithRelations)> {
        let (from_model, to_model) = self.transfer_update(db, transaction_id, data).await?;
        let from_rel = self
            .converter()
            .model_to_with_relations(db, from_model)
            .await?;
        let to_rel = self
            .converter()
            .model_to_with_relations(db, to_model)
            .await?;
        Ok((from_rel, to_rel))
    }

    pub async fn trans_transfer_delete_with_relations(
        &self,
        db: &DatabaseConnection,
        serial_num: &str,
    ) -> MijiResult<(TransactionWithRelations, TransactionWithRelations)> {
        let (from_model, to_model) = self.transfer_delete(db, serial_num).await?;
        let f = self
            .converter()
            .model_to_with_relations(db, from_model)
            .await?;
        let t = self
            .converter()
            .model_to_with_relations(db, to_model)
            .await?;
        Ok((f, t))
    }

    pub async fn trans_list_with_relations(
        &self,
        db: &DbConn,
        filters: TransactionFilter,
    ) -> MijiResult<Vec<TransactionWithRelations>> {
        let models = self.list_with_filter(db, filters).await?;
        let mut result = Vec::with_capacity(models.len());
        for m in models {
            result.push(self.converter().model_to_with_relations(db, m).await?);
        }
        Ok(result)
    }

    pub async fn trans_list_paged_with_relations(
        &self,
        db: &DbConn,
        query: PagedQuery<TransactionFilter>,
    ) -> MijiResult<PagedResult<TransactionWithRelations>> {
        let paged = self.inner.list_paged(db, query).await?;
        let mut rows_with_relations = Vec::with_capacity(paged.rows.len());

        for m in paged.rows {
            let tx_with_rel = self.converter().model_to_with_relations(db, m).await?;
            rows_with_relations.push(tx_with_rel);
        }

        Ok(PagedResult {
            rows: rows_with_relations,
            total_count: paged.total_count,
            current_page: paged.current_page,
            page_size: paged.page_size,
            total_pages: paged.total_pages,
        })
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

fn parse_json<T: serde::de::DeserializeOwned>(s: &str, field: &str) -> MijiResult<T> {
    serde_json::from_str(s).map_err(|e| {
        AppError::internal_server_error(format!("Failed to parse JSON field '{}': {}", field, e))
    })
}
