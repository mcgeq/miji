use std::{str::FromStr, sync::Arc};

use common::{
    BusinessCode,
    crud::service::{
        CrudConverter, CrudService, GenericCrudService, parse_enum_filed,
        update_entity_columns_simple,
    },
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::{localize::LocalizeModel, transactions::Column as TransactionColumn};
use once_cell::sync::Lazy;
use sea_orm::{
    ActiveModelTrait,
    ActiveValue::Set,
    ColumnTrait, Condition, DatabaseConnection, DatabaseTransaction, DbConn, EntityTrait,
    IntoActiveModel, QueryFilter, QuerySelect, TransactionTrait,
    prelude::{Decimal, Expr, async_trait::async_trait},
    sea_query::{Alias, ExprTrait, Func, SimpleExpr},
};
use serde::{Deserialize, Serialize};
use snafu::GenerateImplicitData;
use tracing::{error, info};
use validator::Validate;

use crate::{
    dto::{
        account::AccountType,
        transactions::{
            CreateTransactionRequest, IncomeExpense, IncomeExpenseRaw, PaymentMethod,
            TransactionStatus, TransactionType, TransactionWithRelations, TransferRequest,
            UpdateTransactionRequest,
        },
    },
    error::MoneyError,
    services::{
        account::get_account_service, currency::get_currency_service, transaction_hooks::NoOpHooks,
    },
};

#[derive(Debug, Clone)]
struct TransactionTypeConfig {
    field: &'static str,
    account_type: &'static str,
    #[allow(dead_code)]
    include_in_total: bool,
}

static TRANSACTION_TYPE_CONFIGS: Lazy<Vec<TransactionTypeConfig>> = Lazy::new(|| {
    vec![
        TransactionTypeConfig {
            field: "bank_savings",
            account_type: "Savings",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "bank_savings",
            account_type: "Bank",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "cash",
            account_type: "Cash",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "credit_card",
            account_type: "CreditCard",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "investment",
            account_type: "Investment",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "alipay",
            account_type: "Alipay",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "wechat",
            account_type: "WeChat",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "cloud_quick_pass",
            account_type: "CloudQuickPass",
            include_in_total: true,
        },
        TransactionTypeConfig {
            field: "other",
            account_type: "Other",
            include_in_total: true,
        },
    ]
});

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
        account_active.serial_num = Set(account.serial_num.clone());
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

        info!("from_account {:?}", from_account);
        info!("to_account {:?}", to_account);

        let (from_request, mut to_request) =
            self.build_transfer_requests(&data, &from_account, &to_account)?;

        info!("from_request {:?}", from_request);
        info!("to_request {:?}", to_request);

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

        info!("from_model {:?}", from_model);
        info!("to_model {:?}", to_model);

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
        info!(
            "Starting transfer update for transaction_id: {}",
            transaction_id
        );

        // Step 1: Validate input data
        data.validate().map_err(|e| {
            error!("Validation failed for transfer update: {:?}", e);
            AppError::from_validation_errors(e)
        })?;
        if data.amount.is_sign_negative() {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Transfer amount must be non-negative",
            ));
        }

        let tx = db.begin().await?;

        // Step 2: Fetch original transfer pair Model
        let (original_outgoing, original_incoming) =
            self.fetch_related_transfer(&tx, transaction_id).await?;

        if original_incoming.category != "Transfer"
            || TransactionType::from_str(&original_incoming.transaction_type)?
                != TransactionType::Income
        {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Only Income Transfer transactions can be updated",
            ));
        }

        // Step 3: Validate refund amount
        let original_amount = original_outgoing.amount.abs();
        let refund_amount = data.amount;
        if refund_amount > original_amount {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "Refund amount cannot exceed original transaction amount",
            ));
        }

        // Step 4: Re-fetch from_account for balance check
        let from_account = self.fetch_account(&tx, &data.account_serial_num).await?;
        if from_account.balance < refund_amount {
            return Err(MoneyError::InsufficientFunds {
                balance: refund_amount,
                backtrace: snafu::Backtrace::generate(),
            }
            .into());
        }
        let to_account = self.fetch_account(&tx, &data.to_account_serial_num).await?;

        // Step 5: Apply refund_amount to accounts
        self.apply_balances(&tx, &from_account, &to_account, refund_amount)
            .await?;

        // Step 6: Update original_incoming refund_amount and notes
        let update_at = DateUtils::local_now();
        let update_refund = |model: &entity::transactions::Model, prefix: &str| {
            let refund_amount_all = model.refund_amount + data.amount;
            entity::transactions::ActiveModel {
                serial_num: Set(model.serial_num.clone()),
                refund_amount: Set(refund_amount_all),
                notes: Set(Some(format!("{prefix} {refund_amount_all}"))),
                updated_at: Set(Some(update_at)),
                ..Default::default()
            }
        };

        let update_original_incoming = update_refund(&original_incoming, "退").update(&tx).await?;
        info!("Original_outgoing update {:?}", update_original_incoming);
        let update_original_outgoing = update_refund(&original_outgoing, "进").update(&tx).await?;
        info!("Original_outgoing update {:?}", update_original_outgoing);

        // Step 8: Build and update transaction requests
        let (mut from_request, mut to_request) =
            self.build_transfer_requests(&data, &from_account, &to_account)?;
        let set_completed = |req: &mut CreateTransactionRequest| {
            req.transaction_status = TransactionStatus::Completed;
        };
        set_completed(&mut from_request);
        set_completed(&mut to_request);

        from_request.related_transaction_serial_num = Some(original_incoming.serial_num.clone());
        to_request.related_transaction_serial_num = Some(original_outgoing.serial_num.clone());
        from_request.description = format!("退 {}", to_account.name.clone());
        to_request.description = format!("退 {}", from_account.name.clone());

        let to_active_model =
            |request: CreateTransactionRequest| -> MijiResult<entity::transactions::ActiveModel> {
                let mut model = entity::transactions::ActiveModel::try_from(request)?;
                model.related_transaction_serial_num =
                    Set(original_incoming.related_transaction_serial_num.clone());
                Ok(model)
            };

        let from_active_model = to_active_model(from_request)?;
        let to_active_model = to_active_model(to_request)?;

        let updated_outgoing = from_active_model.insert(&tx).await?;
        let updated_incoming = to_active_model.insert(&tx).await?;

        // Step 9: Log updates
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

        // Step 10: Commit transaction
        tx.commit().await?;

        info!(
            "Transfer update completed successfully for transaction_id: {}",
            transaction_id
        );
        Ok((updated_outgoing, updated_incoming))
    }

    pub async fn transfer_delete(
        &self,
        db: &DatabaseConnection,
        transaction_id: &str,
    ) -> MijiResult<(entity::transactions::Model, entity::transactions::Model)> {
        let tx = db.begin().await?;
        info!("开始删除转账，交易ID: {}", transaction_id);

        let result = async {
            // 步骤1：获取转账交易对
            info!("获取交易ID为 {} 的转账对", transaction_id);
            let (original_outgoing, original_incoming) =
                self.fetch_related_transfer(&tx, transaction_id).await?;
            info!("获取到转出交易: {:?}", original_outgoing);
            info!("获取到转入交易: {:?}", original_incoming);

            // 步骤2：恢复账户余额
            let amount = original_outgoing.amount.abs();
            info!("恢复余额，金额: {}", amount);
            self.revert_balances(&tx, &original_outgoing, &original_incoming, amount)
                .await?;

            // 步骤3：标记原始交易为删除
            let updated_outgoing = self
                .mark_transaction_deleted(&tx, original_outgoing.clone())
                .await?;
            let updated_incoming = self
                .mark_transaction_deleted(&tx, original_incoming.clone())
                .await?;
            info!(
                "转出交易已标记删除: serial_num={}, is_deleted={}",
                updated_outgoing.serial_num, updated_outgoing.is_deleted
            );
            info!(
                "转入交易已标记删除: serial_num={}, is_deleted={}",
                updated_incoming.serial_num, updated_incoming.is_deleted
            );

            // 步骤4：创建并插入反向交易
            let (reverse_out_request, mut reverse_in_request) =
                self.build_reversal_requests(&original_outgoing, &original_incoming, amount);
            info!("反向转出请求: {:?}", reverse_out_request);
            info!("反向转入请求: {:?}", reverse_in_request);

            let converter = TransactionConverter;
            let reverse_out_model = converter
                .create_to_active_model(reverse_out_request)
                .map_err(|e| {
                    error!("转换反向转出请求失败: {:?}", e);
                    e
                })?
                .insert(&tx)
                .await
                .map_err(|e| {
                    error!("插入反向转出交易失败: {:?}", e);
                    e
                })?;
            info!(
                "插入反向转出交易: serial_num={}",
                reverse_out_model.serial_num
            );

            reverse_in_request.related_transaction_serial_num =
                Some(reverse_out_model.serial_num.clone());
            let reverse_in_model = converter
                .create_to_active_model(reverse_in_request)
                .map_err(|e| {
                    info!("转换反向转入请求失败: {:?}", e);
                    e
                })?
                .insert(&tx)
                .await
                .map_err(|e| {
                    info!("插入反向转入交易失败: {:?}", e);
                    e
                })?;
            info!(
                "插入反向转入交易: serial_num={}",
                reverse_in_model.serial_num
            );

            // 步骤5：记录日志
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

            Ok((reverse_out_model, reverse_in_model))
        }
        .await;

        match result {
            Ok(models) => {
                tx.commit().await?;
                Ok(models)
            }
            Err(e) => {
                error!("transfer_delete 错误: {:?}", e);
                tx.rollback().await?;
                Err(e)
            }
        }
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
        let mut active = model.clone().into_active_model();
        active.serial_num = Set(model.serial_num.clone());
        active.is_deleted = Set(true);
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
        let date = data.date.unwrap_or(DateUtils::local_now());

        // 根据是否为空生成默认描述
        let from_description = if let Some(desc) = &data.description {
            if desc.trim().is_empty() {
                format!("转账至 {}", to_account.name)
            } else {
                desc.clone()
            }
        } else {
            format!("转账至 {}", to_account.name)
        };

        let to_description = if let Some(desc) = &data.description {
            if desc.trim().is_empty() {
                format!("转账来自 {}", from_account.name)
            } else {
                desc.clone()
            }
        } else {
            format!("转账来自 {}", from_account.name)
        };

        let from_request = CreateTransactionRequest {
            transaction_type: TransactionType::Expense,
            transaction_status: TransactionStatus::Completed,
            date,
            amount: data.amount,
            currency: data.currency.clone(),
            description: from_description,
            account_serial_num: from_account.serial_num.clone(),
            to_account_serial_num: Some(to_account.serial_num.clone()),
            category: "Transfer".to_string(),
            notes: data.description.clone(),
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
            description: to_description,
            notes: data.description.clone(),
            account_serial_num: to_account.serial_num.clone(),
            to_account_serial_num: Some(from_account.serial_num.clone()),
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
        let date = DateUtils::local_now();

        // 解析原交易描述
        fn swap_transfer_description(desc: &str) -> String {
            let desc = desc.trim();
            let mut from = "";
            let mut to = "";
            for part in desc.split_whitespace() {
                if part.starts_with("转账至") {
                    to = part.trim_start_matches("转账至");
                } else if part.starts_with("转账来自") {
                    from = part.trim_start_matches("转账来自");
                }
            }
            if from.is_empty() && to.is_empty() {
                format!("冲正：{desc}") // 如果无法解析，则直接加“冲正：”
            } else {
                format!("冲正：转账来自 {from} 转账至 {to}")
            }
        }

        let reverse_out_description = if outgoing.description.trim().is_empty() {
            format!(
                "冲正：转账来自 {} 转账至 {}",
                incoming.account_serial_num, outgoing.account_serial_num
            )
        } else {
            swap_transfer_description(&outgoing.description)
        };

        let reverse_in_description = if incoming.description.trim().is_empty() {
            format!(
                "冲正：转账来自 {} 转账至 {}",
                outgoing.account_serial_num, incoming.account_serial_num
            )
        } else {
            swap_transfer_description(&incoming.description)
        };

        let reverse_out_request = CreateTransactionRequest {
            transaction_type: TransactionType::Expense,
            transaction_status: TransactionStatus::Reversed,
            date,
            amount,
            currency: outgoing.currency.clone(),
            description: reverse_out_description,
            notes: outgoing.notes.clone(),
            account_serial_num: incoming.account_serial_num.clone(),
            to_account_serial_num: Some(outgoing.account_serial_num.clone()),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: parse_enum_filed(
                &outgoing.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_enum_filed(
                &outgoing.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: None,
        };

        let reverse_in_request = CreateTransactionRequest {
            transaction_type: TransactionType::Income,
            transaction_status: TransactionStatus::Reversed,
            date,
            amount,
            currency: outgoing.currency.clone(),
            description: reverse_in_description,
            notes: incoming.notes.clone(),
            account_serial_num: outgoing.account_serial_num.clone(),
            to_account_serial_num: Some(incoming.account_serial_num.clone()),
            category: "Transfer".to_string(),
            sub_category: None,
            tags: None,
            split_members: None,
            payment_method: parse_enum_filed(
                &outgoing.payment_method,
                "payment_method",
                PaymentMethod::Other,
            ),
            actual_payer_account: parse_enum_filed(
                &outgoing.actual_payer_account,
                "actual_payer_account",
                AccountType::Savings,
            ),
            related_transaction_serial_num: None,
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

        // 单向关联
        // let related_id = outgoing
        //     .related_transaction_serial_num
        //     .clone()
        //     .ok_or_else(|| {
        //         AppError::simple(BusinessCode::NotFound, "Missing related transaction")
        //     })?;

        let incoming = entity::transactions::Entity::find()
            .filter(entity::transactions::Column::RelatedTransactionSerialNum.eq(transaction_id))
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
                active_model.created_at = Set(model.created_at);
                active_model.updated_at = Set(Some(DateUtils::local_now()));
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
                let serial_nums: Vec<String> = model
                    .split_members
                    .iter()
                    .filter_map(|v| v.as_str().map(|s| s.to_string()))
                    .collect();
                entity::family_member::Entity::find()
                    .filter(entity::family_member::Column::SerialNum.is_in(serial_nums))
                    .all(db)
                    .await
                    .map_err(Into::into)
            }
        )?;
        Ok(TransactionWithRelations {
            transaction: model.to_local(),
            account,
            currency: currency.to_local(),
            family_member: family_member.into_iter().map(|f| f.to_local()).collect(),
        })
    }
}

// 交易过滤器
#[derive(Debug, Clone, Validate, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransactionFilter {
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
    pub is_deleted: Option<bool>,
}

impl Filter<entity::transactions::Entity> for TransactionFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();

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
        let is_deleted = self.is_deleted.unwrap_or_default();
        condition = condition.add(entity::transactions::Column::IsDeleted.eq(is_deleted as i32));

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

    pub async fn trans_delete_with_relations(
        &self,
        db: &DbConn,
        serial_num: &str,
    ) -> MijiResult<()> {
        update_entity_columns_simple::<entity::transactions::Entity, _>(
            db,
            vec![(entity::transactions::Column::SerialNum, vec![serial_num])],
            vec![
                (entity::transactions::Column::IsDeleted, Expr::value(true)),
                (
                    entity::transactions::Column::UpdatedAt,
                    Expr::value(DateUtils::local_now()),
                ),
            ],
        )
        .await
        .map(|_| ())
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

    pub async fn query_income_and_expense(
        &self,
        db: &DatabaseConnection,
        start_date: String,
        end_date: String,
    ) -> MijiResult<IncomeExpense> {
        let mut query = entity::transactions::Entity::find()
            .select_only()
            .filter(TransactionColumn::IsDeleted.eq(0))
            .filter(TransactionColumn::Date.gte(start_date))
            .filter(TransactionColumn::Date.lt(end_date));

        // Total income and expense
        let total_income_expr = Expr::val(0.0).add(
            SimpleExpr::FunctionCall(Func::coalesce(vec![
                SimpleExpr::FunctionCall(Func::sum(
                    Expr::case(
                        Condition::all()
                            .add(TransactionColumn::TransactionType.eq("Income"))
                            .add(TransactionColumn::Category.ne("Transfer")),
                        Expr::col(TransactionColumn::Amount),
                    )
                    .finally(0.0)
                    .cast_as(Alias::new("DECIMAL(16,4)")),
                )),
                Expr::val(0.0).into(),
            ]))
            .cast_as(Alias::new("DECIMAL(16,4)")),
        );

        let total_expense_expr = Expr::val(0.0).add(
            SimpleExpr::FunctionCall(Func::coalesce(vec![
                SimpleExpr::FunctionCall(Func::sum(
                    Expr::case(
                        Condition::all()
                            .add(TransactionColumn::TransactionType.eq("Expense"))
                            .add(TransactionColumn::Category.ne("Transfer")),
                        Expr::col(TransactionColumn::Amount),
                    )
                    .finally(0.0)
                    .cast_as(Alias::new("DECIMAL(16,4)")),
                )),
                Expr::val(0.0).into(),
            ]))
            .cast_as(Alias::new("DECIMAL(16,4)")),
        );

        // Transfer income and expense
        let transfer_income_expr = Expr::val(0.0).add(
            SimpleExpr::FunctionCall(Func::coalesce(vec![
                SimpleExpr::FunctionCall(Func::sum(
                    Expr::case(
                        Condition::all()
                            .add(TransactionColumn::TransactionType.eq("Income"))
                            .add(TransactionColumn::Category.eq("Transfer"))
                            .add(TransactionColumn::ActualPayerAccount.ne("CreditCard")),
                        Expr::col(TransactionColumn::Amount),
                    )
                    .finally(0.0)
                    .cast_as(Alias::new("DECIMAL(16,4)")),
                )),
                Expr::val(0.0).into(),
            ]))
            .cast_as(Alias::new("DECIMAL(16,4)")),
        );

        let transfer_expense_expr = Expr::val(0.0).add(
            SimpleExpr::FunctionCall(Func::coalesce(vec![
                SimpleExpr::FunctionCall(Func::sum(
                    Expr::case(
                        Condition::all()
                            .add(TransactionColumn::TransactionType.eq("Expense"))
                            .add(TransactionColumn::Category.eq("Transfer"))
                            .add(TransactionColumn::ActualPayerAccount.ne("CreditCard")),
                        Expr::col(TransactionColumn::Amount),
                    )
                    .finally(0.0)
                    .cast_as(Alias::new("DECIMAL(16,4)")),
                )),
                Expr::val(0.0).into(),
            ]))
            .cast_as(Alias::new("DECIMAL(16,4)")),
        );

        query = query
            .expr_as(total_income_expr, "total")
            .expr_as(total_expense_expr, "total_expense")
            .expr_as(transfer_income_expr, "transfer_income")
            .expr_as(transfer_expense_expr, "transfer_expense");

        // Add account type specific sums
        for config in TRANSACTION_TYPE_CONFIGS.iter() {
            let income_expr = Expr::val(0.0).add(
                SimpleExpr::FunctionCall(Func::coalesce(vec![
                    SimpleExpr::FunctionCall(Func::sum(
                        Expr::case(
                            Condition::all()
                                .add(TransactionColumn::TransactionType.eq("Income"))
                                .add(TransactionColumn::ActualPayerAccount.eq(config.account_type)),
                            Expr::col(TransactionColumn::Amount),
                        )
                        .finally(0.0)
                        .cast_as(Alias::new("DECIMAL(16,4)")),
                    )),
                    Expr::val(0.0).into(),
                ]))
                .cast_as(Alias::new("DECIMAL(16,4)")),
            );

            let expense_expr = Expr::val(0.0).add(
                SimpleExpr::FunctionCall(Func::coalesce(vec![
                    SimpleExpr::FunctionCall(Func::sum(
                        Expr::case(
                            Condition::all()
                                .add(TransactionColumn::TransactionType.eq("Expense"))
                                .add(TransactionColumn::ActualPayerAccount.eq(config.account_type)),
                            Expr::col(TransactionColumn::Amount),
                        )
                        .finally(0.0)
                        .cast_as(Alias::new("DECIMAL(16,4)")),
                    )),
                    Expr::val(0.0).into(),
                ]))
                .cast_as(Alias::new("DECIMAL(16,4)")),
            );

            query = query
                .expr_as(income_expr, format!("{}_income", config.field))
                .expr_as(expense_expr, format!("{}_expense", config.field));
        }

        let result = query
            .into_model::<IncomeExpenseRaw>()
            .one(db)
            .await
            .map_err(AppError::from)?
            .map(IncomeExpense::from)
            .unwrap_or(IncomeExpense::default());

        Ok(result)
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
        AppError::internal_server_error(format!("Failed to parse JSON field '{field}': {e}"))
    })
}
