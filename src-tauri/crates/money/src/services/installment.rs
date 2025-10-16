use std::sync::Arc;

use chrono::{DateTime, FixedOffset};
use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    paginations::{EmptyFilter, PagedQuery, PagedResult},
    utils::{date::DateUtils, uuid::McgUuid},
};
use sea_orm::{
    ActiveModelTrait, ActiveValue, ColumnTrait, DatabaseConnection, DbConn, EntityTrait,
    IntoActiveModel, QueryFilter, QueryOrder, Set, TransactionTrait, prelude::Decimal,
    prelude::async_trait::async_trait,
};
use tracing::info;
use validator::Validate;

use crate::dto::installment::{
    InstallmentDetailResponse, InstallmentDetailStatus, InstallmentPlanCreate,
    InstallmentPlanResponse, InstallmentPlanUpdate, InstallmentStatus, PayInstallmentCreate,
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
    // 基础 CRUD 操作
    pub async fn installment_plan_get(
        &self,
        db: &DbConn,
        id: String,
    ) -> MijiResult<entity::installment_plans::Model> {
        let model = self.get_by_id(db, id).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn installment_plan_create(
        &self,
        db: &DbConn,
        data: InstallmentPlanCreate,
    ) -> MijiResult<entity::installment_plans::Model> {
        let model = self.create(db, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn installment_plan_update(
        &self,
        db: &DbConn,
        id: String,
        data: InstallmentPlanUpdate,
    ) -> MijiResult<entity::installment_plans::Model> {
        let model = self.update(db, id, data).await?;
        self.converter().model_with_local(model).await
    }

    pub async fn installment_plan_delete(&self, db: &DbConn, id: String) -> MijiResult<()> {
        self.delete(db, id).await
    }

    pub async fn installment_plan_list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<InstallmentFilter>,
    ) -> MijiResult<PagedResult<entity::installment_plans::Model>> {
        self.list_paged(db, query)
            .await?
            .map_async(|rows| self.converter().localize_models(rows))
            .await
    }

    pub async fn installment_plan_list(
        &self,
        db: &DbConn,
    ) -> MijiResult<Vec<entity::installment_plans::Model>> {
        let models = self.list(db).await?;
        let mut local_models = Vec::with_capacity(models.len());
        for model in models {
            local_models.push(self.converter().model_with_local(model).await?);
        }
        Ok(local_models)
    }

    // 业务逻辑方法
    /// 创建分期付款计划（包含分期明细）
    pub async fn create_installment_plan_with_details(
        &self,
        db: &DatabaseConnection,
        request: InstallmentPlanCreate,
    ) -> MijiResult<InstallmentPlanResponse> {
        let tx = db.begin().await?;

        // 1. 创建分期计划
        let plan_id = McgUuid::uuid(38);
        let plan = installment_plans::ActiveModel {
            serial_num: Set(plan_id.clone()),
            transaction_serial_num: Set(request.transaction_serial_num.clone()),
            account_serial_num: Set(request.account_serial_num.clone()),
            total_amount: Set(request.total_amount),
            total_periods: Set(request.total_periods),
            installment_amount: Set(request.installment_amount),
            first_due_date: Set(request.first_due_date),
            status: Set(InstallmentStatus::Active.to_string()),
            created_at: Set(DateUtils::local_now()),
            updated_at: Set(Some(DateUtils::local_now())),
        };

        let plan_model = plan.insert(&tx).await?;

        // 2. 创建分期明细
        let mut details = Vec::new();
        for period in 1..=request.total_periods {
            let due_date = self.calculate_due_date(request.first_due_date, period)?;
            let amount = if period == request.total_periods {
                // 最后一期：总金额 - 前n-1期金额
                request.total_amount - (request.installment_amount * Decimal::from(period - 1))
            } else {
                request.installment_amount
            };

            let detail_id = McgUuid::uuid(38);
            let detail = installment_details::ActiveModel {
                serial_num: Set(detail_id),
                plan_serial_num: Set(plan_id.clone()),
                period_number: Set(period),
                due_date: Set(due_date),
                amount: Set(amount),
                account_serial_num: Set(request.account_serial_num.clone()),
                status: Set(InstallmentDetailStatus::Pending.to_string()),
                paid_date: Set(None),
                paid_amount: Set(None),
                created_at: Set(DateUtils::local_now()),
                updated_at: Set(Some(DateUtils::local_now())),
            };

            let detail_model = detail.insert(&tx).await?;
            details.push(detail_model);
        }

        // 3. 更新交易记录
        let mut transaction_active =
            transactions::Entity::find_by_id(&request.transaction_serial_num)
                .one(&tx)
                .await?
                .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "交易不存在"))?
                .into_active_model();

        transaction_active.installment_plan_serial_num = Set(Some(plan_id.clone()));
        transaction_active.is_installment = Set(Some(true));
        transaction_active.total_periods = Set(Some(request.total_periods));
        transaction_active.remaining_periods = Set(Some(request.total_periods));

        transaction_active.update(&tx).await?;

        tx.commit().await?;

        // 4. 构建响应
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

    /// 处理分期还款
    pub async fn pay_installment(
        &self,
        db: &DatabaseConnection,
        request: PayInstallmentCreate,
    ) -> MijiResult<InstallmentDetailResponse> {
        let tx = db.begin().await?;

        // 1. 查找分期明细
        let mut detail = installment_details::Entity::find_by_id(&request.detail_serial_num)
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "分期明细不存在"))?
            .into_active_model();

        // 2. 检查状态
        if detail.status.as_ref() == &InstallmentDetailStatus::Paid.to_string() {
            return Err(AppError::simple(
                common::BusinessCode::InvalidParameter,
                "该期已还款",
            ));
        }

        // 3. 更新分期明细
        let paid_date = request.paid_date.unwrap_or_else(DateUtils::local_now);
        detail.status = Set(InstallmentDetailStatus::Paid.to_string());
        detail.paid_date = Set(Some(paid_date));
        detail.paid_amount = Set(Some(request.paid_amount));
        detail.updated_at = Set(Some(DateUtils::local_now()));

        let updated_detail = detail.update(&tx).await?;

        // 4. 更新账户余额（这里需要调用账户服务）
        // TODO: 调用账户服务更新余额
        info!("更新账户余额: -{}", request.paid_amount);

        // 5. 更新交易的剩余期数
        let plan = installment_plans::Entity::find_by_id(&updated_detail.plan_serial_num)
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "分期计划不存在"))?;

        let mut transaction_active = transactions::Entity::find_by_id(&plan.transaction_serial_num)
            .one(&tx)
            .await?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "交易不存在"))?
            .into_active_model();

        let current_remaining = transaction_active.remaining_periods.as_ref().unwrap_or(0);
        let new_remaining = current_remaining - 1;
        transaction_active.remaining_periods = Set(Some(new_remaining));

        // 6. 检查是否全部完成
        if new_remaining == 0 {
            transaction_active.transaction_status = Set("Completed".to_string());

            // 更新分期计划状态
            let mut plan_active = plan.into_active_model();
            plan_active.status = Set(InstallmentStatus::Completed.to_string());
            plan_active.updated_at = Set(Some(DateUtils::local_now()));
            plan_active.update(&tx).await?;
        }

        transaction_active.update(&tx).await?;

        tx.commit().await?;

        // 7. 构建响应
        Ok(InstallmentDetailResponse {
            serial_num: updated_detail.serial_num,
            plan_serial_num: updated_detail.plan_serial_num,
            period_number: updated_detail.period_number,
            due_date: updated_detail.due_date,
            amount: updated_detail.amount,
            status: updated_detail.status,
            paid_date: updated_detail.paid_date,
            paid_amount: updated_detail.paid_amount,
            created_at: updated_detail.created_at,
            updated_at: updated_detail.updated_at,
        })
    }

    /// 获取分期付款计划
    pub async fn get_installment_plan(
        &self,
        db: &DbConn,
        installment_plan_serial_num: &str,
    ) -> MijiResult<InstallmentPlanResponse> {
        let plan = installment_plans::Entity::find_by_id(installment_plan_serial_num)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "分期计划不存在"))?;

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

    /// 计算还款日期
    fn calculate_due_date(
        &self,
        first_due_date: DateTime<FixedOffset>,
        period: i32,
    ) -> MijiResult<DateTime<FixedOffset>> {
        if period == 1 {
            return Ok(first_due_date);
        }

        // 简化处理：每月递增30天
        // 实际应用中应该按月份计算
        let days_to_add = (period - 1) * 30;
        Ok(first_due_date + chrono::Duration::days(days_to_add as i64))
    }
}

pub fn get_installment_service() -> InstallmentService {
    InstallmentService::new(
        InstallmentConverter,
        InstallmentHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
