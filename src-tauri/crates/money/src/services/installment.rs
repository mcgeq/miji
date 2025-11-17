use std::str::FromStr;
use std::sync::Arc;

use chrono::{Datelike, NaiveDate};
use common::{
    BusinessCode,
    crud::service::{CrudConverter, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::EmptyFilter,
    utils::{date::DateUtils, uuid::McgUuid},
};
use sea_orm::{
    ActiveModelTrait, ActiveValue, ColumnTrait, DatabaseConnection, DbConn, EntityTrait,
    IntoActiveModel, PaginatorTrait, QueryFilter, QueryOrder, Set, TransactionTrait,
    prelude::Decimal, prelude::async_trait::async_trait,
};
use validator::Validate;

use crate::dto::account::AccountType;
use crate::dto::installment::{
    InstallmentCalculationRequest, InstallmentCalculationResponse, InstallmentDetailResponse,
    InstallmentDetailStatus, InstallmentPlanCreate, InstallmentPlanResponse, InstallmentPlanUpdate,
    InstallmentStatus,
};
use crate::dto::transactions::{
    CreateTransactionRequest, PaymentMethod, TransactionStatus, TransactionType,
};
use crate::services::installment_hooks::InstallmentHooks;
use entity::{installment_details, installment_plans, transactions};

pub type InstallmentFilter = EmptyFilter;

#[derive(Debug)]
pub struct InstallmentConverter;

impl CrudConverter<entity::installment_plans::Entity, InstallmentPlanCreate, InstallmentPlanUpdate>
    for InstallmentConverter
{
    fn create_to_active_model(
        &self,
        data: InstallmentPlanCreate,
    ) -> MijiResult<entity::installment_plans::ActiveModel> {
        entity::installment_plans::ActiveModel::try_from(data).map_err(|errors| {
            AppError::simple(
                common::BusinessCode::InvalidParameter,
                format!("failed {errors}"),
            )
        })
    }

    fn update_to_active_model(
        &self,
        model: entity::installment_plans::Model,
        data: InstallmentPlanUpdate,
    ) -> MijiResult<entity::installment_plans::ActiveModel> {
        data.validate().map_err(AppError::from_validation_errors)?;

        let mut active_model = entity::installment_plans::ActiveModel {
            serial_num: ActiveValue::Set(model.serial_num.clone()),
            transaction_serial_num: ActiveValue::Set(model.transaction_serial_num.clone()),
            account_serial_num: ActiveValue::Set(model.account_serial_num.clone()),
            total_amount: ActiveValue::Set(model.total_amount),
            total_periods: ActiveValue::Set(model.total_periods),
            installment_amount: ActiveValue::Set(model.installment_amount),
            first_due_date: ActiveValue::Set(model.first_due_date),
            status: ActiveValue::Set(model.status.clone()),
            created_at: ActiveValue::Set(model.created_at),
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        };

        // 只更新提供的字段
        if let Some(status) = data.status {
            active_model.status = ActiveValue::Set(status);
        }

        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::installment_plans::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "installment_plans"
    }
}

#[async_trait]
impl LocalizableConverter<entity::installment_plans::Model> for InstallmentConverter {
    async fn model_with_local(
        &self,
        model: entity::installment_plans::Model,
    ) -> MijiResult<entity::installment_plans::Model> {
        Ok(model)
    }
}

pub struct InstallmentService {
    inner: GenericCrudService<
        entity::installment_plans::Entity,
        InstallmentFilter,
        InstallmentPlanCreate,
        InstallmentPlanUpdate,
        InstallmentConverter,
        InstallmentHooks,
    >,
}

impl Default for InstallmentService {
    fn default() -> Self {
        Self::new(
            InstallmentConverter,
            InstallmentHooks,
            Arc::new(common::log::logger::NoopLogger),
        )
    }
}

impl InstallmentService {
    pub fn new(
        converter: InstallmentConverter,
        hooks: InstallmentHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for InstallmentService {
    type Target = GenericCrudService<
        entity::installment_plans::Entity,
        InstallmentFilter,
        InstallmentPlanCreate,
        InstallmentPlanUpdate,
        InstallmentConverter,
        InstallmentHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl InstallmentService {
    // 业务逻辑方法
    /// 在现有事务中创建分期付款计划（包含分期明细）
    pub async fn create_installment_plan_with_details(
        &self,
        tx: &sea_orm::DatabaseTransaction,
        request: InstallmentPlanCreate,
    ) -> MijiResult<InstallmentPlanResponse> {
        let now = DateUtils::local_now();
        // 1. 创建分期计划
        let plan = installment_plans::ActiveModel {
            serial_num: Set(request.serial_num.clone()),
            transaction_serial_num: Set(request.transaction_serial_num.clone()),
            account_serial_num: Set(request.account_serial_num.clone()),
            total_amount: Set(request.total_amount),
            total_periods: Set(request.total_periods),
            installment_amount: Set(request.installment_amount),
            first_due_date: Set(request.first_due_date),
            status: Set(InstallmentStatus::Active.to_string()),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        };

        let plan_model = plan.insert(tx).await?;
        let installment_details_c = InstallmentCalculationRequest {
            total_amount: request.total_amount,
            total_periods: request.total_periods,
            first_due_date: request.first_due_date,
        };
        let period_amount_details = self
            .calculate_installment_amount(installment_details_c)
            .await?;
        // 2. 创建分期明细（批量插入）
        let now = DateUtils::local_now();
        let detail_models: Vec<installment_details::ActiveModel> = period_amount_details
            .details
            .iter()
            .map(|calculation_detail| installment_details::ActiveModel {
                serial_num: Set(McgUuid::uuid(38)),
                plan_serial_num: Set(request.serial_num.clone()),
                period_number: Set(calculation_detail.period),
                due_date: Set(calculation_detail.due_date),
                amount: Set(calculation_detail.amount),
                account_serial_num: Set(request.account_serial_num.clone()),
                status: Set(InstallmentDetailStatus::Pending.to_string()),
                paid_date: Set(None),
                paid_amount: Set(None),
                created_at: Set(now),
                updated_at: Set(Some(now)),
            })
            .collect();

        installment_details::Entity::insert_many(detail_models)
            .exec(tx)
            .await?;

        // 3. 查询插入的分期明细并构建响应
        let details = installment_details::Entity::find()
            .filter(installment_details::Column::PlanSerialNum.eq(&request.serial_num))
            .order_by_asc(installment_details::Column::PeriodNumber)
            .all(tx)
            .await?;

        let detail_responses: Vec<InstallmentDetailResponse> = details
            .into_iter()
            .map(|detail| InstallmentDetailResponse {
                serial_num: detail.serial_num,
                plan_serial_num: detail.plan_serial_num,
                period_number: detail.period_number,
                due_date: detail.due_date,
                amount: detail.amount,
                status: detail.status,
                paid_date: detail.paid_date,
                paid_amount: detail.paid_amount,
                created_at: detail.created_at,
                updated_at: detail.updated_at,
            })
            .collect();

        Ok(InstallmentPlanResponse {
            serial_num: plan_model.serial_num,
            transaction_serial_num: plan_model.transaction_serial_num,
            total_amount: plan_model.total_amount,
            total_periods: plan_model.total_periods,
            installment_amount: plan_model.installment_amount,
            first_due_date: plan_model.first_due_date,
            status: plan_model.status,
            created_at: plan_model.created_at,
            updated_at: plan_model.updated_at,
            details: detail_responses,
        })
    }

    /// 获取分期付款计划（根据分期计划序列号）
    pub async fn get_installment_plan(
        &self,
        db: &DbConn,
        installment_plan_serial_num: &str,
    ) -> MijiResult<InstallmentPlanResponse> {
        let plan = installment_plans::Entity::find_by_id(installment_plan_serial_num)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "分期计划不存在"))?;

        self.build_installment_plan_response(db, plan).await
    }

    /// 获取分期付款计划（根据交易序列号）
    pub async fn get_installment_plan_by_transaction(
        &self,
        db: &DbConn,
        transaction_serial_num: &str,
    ) -> MijiResult<InstallmentPlanResponse> {
        let plan = installment_plans::Entity::find()
            .filter(installment_plans::Column::TransactionSerialNum.eq(transaction_serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "该交易没有分期计划"))?;

        self.build_installment_plan_response(db, plan).await
    }

    /// 构建分期计划响应（内部方法）
    async fn build_installment_plan_response(
        &self,
        db: &DbConn,
        plan: entity::installment_plans::Model,
    ) -> MijiResult<InstallmentPlanResponse> {
        let details = installment_details::Entity::find()
            .filter(installment_details::Column::PlanSerialNum.eq(&plan.serial_num))
            .order_by_asc(installment_details::Column::PeriodNumber)
            .all(db)
            .await?;

        let detail_responses: Vec<InstallmentDetailResponse> = details
            .into_iter()
            .map(|detail| InstallmentDetailResponse {
                serial_num: detail.serial_num,
                plan_serial_num: detail.plan_serial_num,
                period_number: detail.period_number,
                due_date: detail.due_date,
                amount: detail.amount,
                status: detail.status,
                paid_date: detail.paid_date,
                paid_amount: detail.paid_amount,
                created_at: detail.created_at,
                updated_at: detail.updated_at,
            })
            .collect();

        Ok(InstallmentPlanResponse {
            serial_num: plan.serial_num,
            transaction_serial_num: plan.transaction_serial_num,
            total_amount: plan.total_amount,
            total_periods: plan.total_periods,
            installment_amount: plan.installment_amount,
            first_due_date: plan.first_due_date,
            status: plan.status,
            created_at: plan.created_at,
            updated_at: plan.updated_at,
            details: detail_responses,
        })
    }

    /// 获取待还款的分期明细
    pub async fn get_pending_installments(
        &self,
        db: &DatabaseConnection,
        plan_serial_num: &str,
    ) -> MijiResult<Vec<InstallmentDetailResponse>> {
        let details = installment_details::Entity::find()
            .filter(installment_details::Column::PlanSerialNum.eq(plan_serial_num))
            .filter(
                installment_details::Column::Status
                    .eq(InstallmentDetailStatus::Pending.to_string()),
            )
            .order_by_asc(installment_details::Column::DueDate)
            .all(db)
            .await?;

        let responses: Vec<InstallmentDetailResponse> = details
            .into_iter()
            .map(|detail| InstallmentDetailResponse {
                serial_num: detail.serial_num,
                plan_serial_num: detail.plan_serial_num,
                period_number: detail.period_number,
                due_date: detail.due_date,
                amount: detail.amount,
                status: detail.status,
                paid_date: detail.paid_date,
                paid_amount: detail.paid_amount,
                created_at: detail.created_at,
                updated_at: detail.updated_at,
            })
            .collect();

        Ok(responses)
    }

    /// 计算分期金额（纯计算，不涉及数据库操作）
    pub async fn calculate_installment_amount(
        &self,
        request: InstallmentCalculationRequest,
    ) -> MijiResult<InstallmentCalculationResponse> {
        // 验证输入参数
        request
            .validate()
            .map_err(AppError::from_validation_errors)?;

        let total_amount = request.total_amount;
        let total_periods = request.total_periods;
        let first_due_date = request.first_due_date;

        // 计算每期基础金额（向上取整到2位小数）
        // 使用与前端相同的算法：Math.ceil((totalAmount * 100) / totalPeriods) / 100
        let base_amount = (total_amount * Decimal::from(100) / Decimal::from(total_periods)).ceil()
            / Decimal::from(100);

        // 生成分期明细
        let mut details = Vec::new();
        for period in 1..=total_periods {
            let due_date = self.calculate_due_date(first_due_date, period)?;

            let amount = if period == total_periods {
                // 最后一期：总金额 - 前n-1期金额
                total_amount - (base_amount * Decimal::from(period - 1))
            } else {
                base_amount
            };

            details.push(crate::dto::installment::InstallmentCalculationDetail {
                period,
                amount,
                due_date,
            });
        }

        Ok(InstallmentCalculationResponse {
            installment_amount: base_amount,
            details,
        })
    }

    /// 计算还款日期
    fn calculate_due_date(&self, first_due_date: NaiveDate, period: i32) -> MijiResult<NaiveDate> {
        if period == 1 {
            return Ok(first_due_date);
        }

        // 按月份递增，保持每月的同一天
        let months_to_add = period - 1;

        // 使用chrono的内置方法进行月份计算
        let mut current_date = first_due_date;

        for _ in 0..months_to_add {
            // 获取当前日期的年月日
            let year = current_date.year();
            let month = current_date.month();
            let day = current_date.day();

            // 计算下个月
            let (next_year, next_month) = if month == 12 {
                (year + 1, 1)
            } else {
                (year, month + 1)
            };

            // 获取下个月的最后一天
            let last_day_of_next_month = if next_month == 12 {
                NaiveDate::from_ymd_opt(next_year + 1, 1, 1)
            } else {
                NaiveDate::from_ymd_opt(next_year, next_month + 1, 1)
            }
            .and_then(|date| date.pred_opt())
            .map(|date| date.day())
            .unwrap_or(28);

            // 确定目标日期
            let target_day = if day > last_day_of_next_month {
                last_day_of_next_month
            } else {
                day
            };

            // 创建新的日期
            current_date =
                NaiveDate::from_ymd_opt(next_year, next_month, target_day).ok_or_else(|| {
                    AppError::simple(common::BusinessCode::InvalidParameter, "Invalid date")
                })?;
        }

        Ok(current_date)
    }

    /// 自动处理到期的分期付款：获取最小期数的未完成分期明细进行记账
    pub async fn auto_process_due_installments(
        &self,
        db: &DatabaseConnection,
    ) -> MijiResult<Vec<entity::transactions::Model>> {
        let now = DateUtils::local_now();

        // 1. 查询所有未完成的分期明细，按分期计划分组，获取每组的最小期数
        let pending_installment_details = installment_details::Entity::find()
            .filter(
                installment_details::Column::Status
                    .eq(InstallmentDetailStatus::Pending.to_string()),
            )
            .filter(installment_details::Column::DueDate.lte(now))
            .order_by_asc(installment_details::Column::PlanSerialNum)
            .order_by_asc(installment_details::Column::PeriodNumber)
            .all(db)
            .await?;

        if pending_installment_details.is_empty() {
            return Ok(Vec::new());
        }

        // 2. 按分期计划分组，获取每组的最小期数明细
        let mut plan_min_periods = std::collections::HashMap::new();
        for detail in &pending_installment_details {
            let plan_serial_num = &detail.plan_serial_num;
            if !plan_min_periods.contains_key(plan_serial_num) {
                plan_min_periods.insert(plan_serial_num.clone(), detail.clone());
            }
        }

        let mut processed_transactions = Vec::new();

        // 3. 处理每个分期计划的最小期数明细
        let paid_date_now = DateUtils::local_now_naivedate();
        for (plan_serial_num, detail) in plan_min_periods {
            // 获取分期计划信息
            let plan = installment_plans::Entity::find_by_id(&plan_serial_num)
                .one(db)
                .await?
                .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "分期计划不存在"))?;

            // 获取关联的交易信息
            let transaction = transactions::Entity::find_by_id(&plan.transaction_serial_num)
                .one(db)
                .await?
                .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "关联交易不存在"))?;

            // 4. 在单个事务中处理所有操作
            let tx = db.begin().await?;

            // 创建支出交易记录（手动调用 hooks 逻辑）
            let expense_transaction = CreateTransactionRequest {
                transaction_type: TransactionType::Expense,
                transaction_status: TransactionStatus::Completed,
                date: now,
                amount: detail.amount,
                currency: transaction.currency.clone(),
                description: format!(
                    "分期付款第{}期 - {}",
                    detail.period_number, transaction.description
                ),
                notes: Some(format!(
                    "分期计划: {}, 第{}/{}期",
                    plan_serial_num, detail.period_number, plan.total_periods
                )),
                account_serial_num: detail.account_serial_num.clone(),
                to_account_serial_num: None,
                category: transaction.category.clone(),
                sub_category: transaction.sub_category.clone(),
                tags: None,
                payment_method: PaymentMethod::from_str(&transaction.payment_method).map_err(
                    |e| {
                        AppError::simple(
                            BusinessCode::InvalidParameter,
                            format!("无效的支付方式: {e}"),
                        )
                    },
                )?,
                actual_payer_account: AccountType::from_str(&transaction.actual_payer_account)
                    .map_err(|e| {
                        AppError::simple(
                            BusinessCode::InvalidParameter,
                            format!("无效的账户类型: {e}"),
                        )
                    })?,
                related_transaction_serial_num: Some(transaction.serial_num.clone()),
                is_installment: Some(false),
                first_due_date: None,
                total_periods: None,
                remaining_periods_amount: None,
                remaining_periods: None,
                installment_amount: None,
                family_ledger_serial_nums: None,
                split_members: None,
                split_config: None,
            };

            // 手动调用 before_create hooks
            self.call_before_create_hooks(&tx, &expense_transaction)
                .await?;

            // 创建交易记录
            let transaction_model: entity::transactions::ActiveModel =
                expense_transaction.try_into()?;
            let created_transaction = transaction_model.insert(&tx).await?;
            processed_transactions.push(created_transaction.clone());

            // 手动调用 after_create hooks（更新账户余额）
            self.call_after_create_hooks(&tx, &created_transaction)
                .await?;

            // 5. 更新分期明细状态为已支付
            let mut detail_active = detail.clone().into_active_model();
            detail_active.status = Set(InstallmentDetailStatus::Paid.to_string());
            detail_active.paid_date = Set(Some(paid_date_now));
            detail_active.paid_amount = Set(Some(detail.amount));
            detail_active.updated_at = Set(Some(now));
            detail_active.update(&tx).await?;

            // 6. 更新交易记录的剩余期数和金额
            let mut transaction_active = transaction.clone().into_active_model();
            let current_remaining = transaction.remaining_periods.unwrap_or(plan.total_periods);
            let new_remaining = current_remaining - 1;
            let current_remaining_amount = transaction
                .remaining_periods_amount
                .unwrap_or(plan.total_amount);
            let new_remaining_amount = current_remaining_amount - detail.amount;

            transaction_active.remaining_periods = Set(Some(new_remaining));
            transaction_active.remaining_periods_amount = Set(Some(new_remaining_amount));
            transaction_active.updated_at = Set(Some(now));

            // 7. 检查是否为最后一期
            if new_remaining == 0 {
                // 更新交易状态为已完成
                transaction_active.transaction_status = Set("Completed".to_string());

                // 更新分期计划状态为已完成
                let mut plan_active = plan.into_active_model();
                plan_active.status = Set(InstallmentStatus::Completed.to_string());
                plan_active.updated_at = Set(Some(now));
                plan_active.update(&tx).await?;
            }

            transaction_active.update(&tx).await?;
            tx.commit().await?;
        }

        Ok(processed_transactions)
    }

    /// 检查分期付款是否完成
    pub async fn check_installment_completion(
        &self,
        db: &DatabaseConnection,
        parent_serial_num: &str,
    ) -> MijiResult<bool> {
        // 查询所有相关的分期交易
        let installment_transactions = entity::transactions::Entity::find()
            .filter(transactions::Column::RelatedTransactionSerialNum.eq(parent_serial_num))
            .filter(transactions::Column::IsDeleted.eq(false))
            .all(db)
            .await?;

        if installment_transactions.is_empty() {
            return Ok(false);
        }

        // 检查是否所有分期都已完成
        let all_completed = installment_transactions
            .iter()
            .all(|transaction| transaction.transaction_status == "Completed");

        Ok(all_completed)
    }

    /// 更新分期付款的父交易状态
    pub async fn update_installment_parent_status(
        &self,
        db: &DatabaseConnection,
        parent_serial_num: &str,
    ) -> MijiResult<()> {
        let tx = db.begin().await?;

        // 检查分期是否完成
        let is_completed = self
            .check_installment_completion(db, parent_serial_num)
            .await?;

        if is_completed {
            // 更新父交易状态为已完成
            let parent_transaction = entity::transactions::Entity::find()
                .filter(transactions::Column::SerialNum.eq(parent_serial_num))
                .one(&tx)
                .await?
                .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "父交易不存在"))?;

            let mut parent_active = parent_transaction.into_active_model();
            parent_active.transaction_status = Set("Completed".to_string());
            parent_active.updated_at = Set(Some(DateUtils::local_now()));

            parent_active.update(&tx).await?;
        }

        tx.commit().await?;
        Ok(())
    }

    /// 撤销分期付款
    pub async fn reverse_installment_transaction(
        &self,
        db: &DatabaseConnection,
        parent_serial_num: &str,
    ) -> MijiResult<Vec<entity::transactions::Model>> {
        let tx = db.begin().await?;

        // 查询所有相关的分期交易
        let installment_transactions = entity::transactions::Entity::find()
            .filter(transactions::Column::RelatedTransactionSerialNum.eq(parent_serial_num))
            .filter(transactions::Column::IsDeleted.eq(false))
            .all(&tx)
            .await?;

        let mut reversed_transactions = Vec::new();

        for transaction in installment_transactions {
            // 如果分期已经完成，需要创建反向交易
            if transaction.transaction_status == "Completed" {
                let reverse_data = CreateTransactionRequest {
                    transaction_type: TransactionType::from_str(&transaction.transaction_type)
                        .map_err(|e| {
                            AppError::simple(
                                BusinessCode::InvalidParameter,
                                format!("无效的交易类型: {e}"),
                            )
                        })?,
                    transaction_status: TransactionStatus::Reversed,
                    date: DateUtils::local_now(),
                    amount: transaction.amount,
                    currency: transaction.currency.clone(),
                    description: format!("撤销: {}", transaction.description),
                    notes: Some("分期付款撤销".to_string()),
                    account_serial_num: transaction.account_serial_num.clone(),
                    to_account_serial_num: transaction.to_account_serial_num.clone(),
                    category: transaction.category.clone(),
                    sub_category: transaction.sub_category.clone(),
                    tags: None,
                    payment_method: PaymentMethod::from_str(&transaction.payment_method).map_err(
                        |e| {
                            AppError::simple(
                                BusinessCode::InvalidParameter,
                                format!("无效的支付方式: {e}"),
                            )
                        },
                    )?,
                    actual_payer_account: AccountType::from_str(&transaction.actual_payer_account)
                        .map_err(|e| {
                            AppError::simple(
                                BusinessCode::InvalidParameter,
                                format!("无效的账户类型: {e}"),
                            )
                        })?,
                    related_transaction_serial_num: Some(transaction.serial_num.clone()),
                    is_installment: Some(false),
                    first_due_date: None,
                    total_periods: None,
                    remaining_periods_amount: Some(Decimal::ZERO),
                    remaining_periods: None,
                    installment_amount: Some(Decimal::ZERO),
                    family_ledger_serial_nums: None,
                    split_members: None,
                    split_config: None,
                };

                let reverse_model: entity::transactions::ActiveModel = reverse_data.try_into()?;
                let reverse_transaction = reverse_model.insert(&tx).await?;

                // 更新账户余额
                self.update_account_balance_for_transaction(&tx, &reverse_transaction)
                    .await?;

                reversed_transactions.push(reverse_transaction);
            }

            // 更新分期交易状态为已撤销
            let mut transaction_active = transaction.into_active_model();
            transaction_active.transaction_status = Set("Reversed".to_string());
            transaction_active.updated_at = Set(Some(DateUtils::local_now()));

            let updated_transaction = transaction_active.update(&tx).await?;
            reversed_transactions.push(updated_transaction);
        }

        // 更新父交易状态
        let mut parent_transaction = entity::transactions::Entity::find()
            .filter(transactions::Column::SerialNum.eq(parent_serial_num))
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "父交易不存在"))?
            .into_active_model();

        parent_transaction.transaction_status = Set("Reversed".to_string());
        parent_transaction.updated_at = Set(Some(DateUtils::local_now()));
        parent_transaction.update(&tx).await?;

        tx.commit().await?;
        Ok(reversed_transactions)
    }

    /// 手动调用 before_create hooks
    async fn call_before_create_hooks(
        &self,
        tx: &sea_orm::DatabaseTransaction,
        data: &CreateTransactionRequest,
    ) -> MijiResult<()> {
        use crate::services::transaction_hooks::NoOpHooks;
        use common::crud::hooks::Hooks;

        let hooks = NoOpHooks;
        hooks.before_create(tx, data).await?;
        Ok(())
    }

    /// 手动调用 after_create hooks
    async fn call_after_create_hooks(
        &self,
        tx: &sea_orm::DatabaseTransaction,
        model: &entity::transactions::Model,
    ) -> MijiResult<()> {
        use crate::services::transaction_hooks::NoOpHooks;
        use common::crud::hooks::Hooks;

        let hooks = NoOpHooks;
        hooks.after_create(tx, model).await?;
        Ok(())
    }

    /// 更新账户余额（内部方法）
    async fn update_account_balance_for_transaction(
        &self,
        tx: &sea_orm::DatabaseTransaction,
        transaction: &entity::transactions::Model,
    ) -> MijiResult<()> {
        use crate::services::transaction_hooks::update_account_balance;

        let transaction_type =
            TransactionType::from_str(&transaction.transaction_type).map_err(|e| {
                AppError::simple(
                    BusinessCode::InvalidParameter,
                    format!("无效的交易类型: {e}"),
                )
            })?;
        update_account_balance(
            tx,
            &transaction.account_serial_num,
            transaction_type,
            transaction.amount,
            false,
        )
        .await?;

        Ok(())
    }

    /// 检查交易是否有已完成的分期付款
    pub async fn has_paid_installments(
        &self,
        db: &DbConn,
        transaction_serial_num: &str,
    ) -> MijiResult<bool> {
        // 首先查找该交易的分期计划
        let plan = installment_plans::Entity::find()
            .filter(installment_plans::Column::TransactionSerialNum.eq(transaction_serial_num))
            .one(db)
            .await?;

        if let Some(plan) = plan {
            // 检查是否有状态为PAID的分期明细
            let paid_count = installment_details::Entity::find()
                .filter(installment_details::Column::PlanSerialNum.eq(&plan.serial_num))
                .filter(installment_details::Column::Status.eq("PAID"))
                .count(db)
                .await?;

            Ok(paid_count > 0)
        } else {
            // 没有分期计划，返回false
            Ok(false)
        }
    }
}
