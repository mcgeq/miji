use crate::dto::family_budget::{
    BudgetAllocationCreateRequest, BudgetAllocationResponse, BudgetAllocationUpdateRequest,
    BudgetAlertResponse,
};
use common::{
    BusinessCode,
    error::{AppError, MijiResult},
    utils::{date::DateUtils, uuid::McgUuid},
};
use num_traits::ToPrimitive;
use sea_orm::{
    prelude::Decimal,
    ActiveModelTrait, ColumnTrait, Condition, DbConn, EntityTrait, PaginatorTrait, QueryFilter,
    QueryOrder, QuerySelect, Set,
};

/// 预算分配服务
pub struct BudgetAllocationService;

impl BudgetAllocationService {
    /// 创建预算分配
    pub async fn create(
        db: &DbConn,
        budget_serial_num: &str,
        data: BudgetAllocationCreateRequest,
    ) -> MijiResult<entity::budget_allocations::Model> {
        // 1. 验证输入
        if data.category_serial_num.is_none() && data.member_serial_num.is_none() {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "category_serial_num 和 member_serial_num 不能同时为空",
            ));
        }

        // 2. 获取预算信息
        let budget = entity::budget::Entity::find()
            .filter(entity::budget::Column::SerialNum.eq(budget_serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "预算不存在"))?;

        // 3. 计算分配金额
        let allocated_amount = if let Some(percentage) = data.percentage {
            budget.amount * (percentage / Decimal::from(100))
        } else {
            data.allocated_amount
                .ok_or_else(|| AppError::simple(
                    BusinessCode::InvalidParameter,
                    "必须指定 allocated_amount 或 percentage",
                ))?
        };

        // 4. 验证总分配不超预算
        let total_allocated = Self::get_total_allocated(db, budget_serial_num).await?;
        if total_allocated + allocated_amount > budget.amount {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "分配总额超过预算总额",
            ));
        }

        // 5. 检查重复分配
        if Self::check_duplicate(
            db,
            budget_serial_num,
            data.category_serial_num.as_deref(),
            data.member_serial_num.as_deref(),
        )
        .await?
        {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "该分类和成员组合已存在分配记录",
            ));
        }

        // 6. 检查百分比分配的总和不能超过100%
        if let Some(percentage) = data.percentage {
            if percentage > Decimal::from(100) {
                return Err(AppError::simple(
                    BusinessCode::InvalidParameter,
                    "百分比分配的总和不能超过100%",
                ));
            }
        }

        // 6. 创建分配记录
        let now = DateUtils::local_now();
        let allocation = entity::budget_allocations::ActiveModel {
            serial_num: Set(McgUuid::uuid(38)),
            budget_serial_num: Set(budget_serial_num.to_string()),
            category_serial_num: Set(data.category_serial_num),
            member_serial_num: Set(data.member_serial_num),
            allocated_amount: Set(allocated_amount),
            used_amount: Set(Decimal::ZERO),
            remaining_amount: Set(allocated_amount),
            percentage: Set(data.percentage),
            // 分配规则
            allocation_type: Set(data.allocation_type.unwrap_or("FIXED_AMOUNT".to_string())),
            rule_config: Set(data.rule_config),
            // 超支控制
            allow_overspend: Set(data.allow_overspend.unwrap_or(false)),
            overspend_limit_type: Set(data.overspend_limit_type),
            overspend_limit_value: Set(data.overspend_limit_value),
            // 预警设置
            alert_enabled: Set(data.alert_enabled.unwrap_or(true)),
            alert_threshold: Set(data.alert_threshold.unwrap_or(80)),
            alert_config: Set(data.alert_config),
            // 管理字段
            priority: Set(data.priority.unwrap_or(3)),
            is_mandatory: Set(data.is_mandatory.unwrap_or(false)),
            status: Set("ACTIVE".to_string()),
            notes: Set(data.notes),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        };

        let result = allocation.insert(db).await?;
        Ok(result)
    }

    /// 更新预算分配
    pub async fn update(
        db: &DbConn,
        serial_num: &str,
        data: BudgetAllocationUpdateRequest,
    ) -> MijiResult<entity::budget_allocations::Model> {
        let allocation = entity::budget_allocations::Entity::find()
            .filter(entity::budget_allocations::Column::SerialNum.eq(serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "分配记录不存在"))?;

        let mut active_model: entity::budget_allocations::ActiveModel = allocation.clone().into();

        // 更新基础字段
        if let Some(allocated_amount) = data.allocated_amount {
            active_model.allocated_amount = Set(allocated_amount);
            active_model.remaining_amount =
                Set(allocated_amount - allocation.used_amount);
        }
        if let Some(percentage) = data.percentage {
            active_model.percentage = Set(Some(percentage));
        }

        // 更新增强字段
        if let Some(allocation_type) = data.allocation_type {
            active_model.allocation_type = Set(allocation_type);
        }
        if data.rule_config.is_some() {
            active_model.rule_config = Set(data.rule_config);
        }
        if let Some(allow_overspend) = data.allow_overspend {
            active_model.allow_overspend = Set(allow_overspend);
        }
        if data.overspend_limit_type.is_some() {
            active_model.overspend_limit_type = Set(data.overspend_limit_type);
        }
        if data.overspend_limit_value.is_some() {
            active_model.overspend_limit_value = Set(data.overspend_limit_value);
        }
        if let Some(alert_enabled) = data.alert_enabled {
            active_model.alert_enabled = Set(alert_enabled);
        }
        if let Some(alert_threshold) = data.alert_threshold {
            active_model.alert_threshold = Set(alert_threshold);
        }
        if data.alert_config.is_some() {
            active_model.alert_config = Set(data.alert_config);
        }
        if let Some(priority) = data.priority {
            active_model.priority = Set(priority);
        }
        if let Some(is_mandatory) = data.is_mandatory {
            active_model.is_mandatory = Set(is_mandatory);
        }
        if let Some(status) = data.status {
            active_model.status = Set(status);
        }
        if data.notes.is_some() {
            active_model.notes = Set(data.notes);
        }

        active_model.updated_at = Set(Some(DateUtils::local_now()));

        let result = active_model.update(db).await?;
        Ok(result)
    }

    /// 删除预算分配
    pub async fn delete(db: &DbConn, serial_num: &str) -> MijiResult<()> {
        entity::budget_allocations::Entity::delete_by_id(serial_num)
            .exec(db)
            .await?;
        Ok(())
    }

    /// 获取预算分配详情
    pub async fn get(
        db: &DbConn,
        serial_num: &str,
    ) -> MijiResult<entity::budget_allocations::Model> {
        entity::budget_allocations::Entity::find()
            .filter(entity::budget_allocations::Column::SerialNum.eq(serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "分配记录不存在"))
    }

    /// 查询预算的所有分配
    pub async fn list_by_budget(
        db: &DbConn,
        budget_serial_num: &str,
    ) -> MijiResult<Vec<entity::budget_allocations::Model>> {
        let allocations = entity::budget_allocations::Entity::find()
            .filter(entity::budget_allocations::Column::BudgetSerialNum.eq(budget_serial_num))
            .order_by_desc(entity::budget_allocations::Column::Priority)
            .all(db)
            .await?;
        Ok(allocations)
    }

    /// 记录预算使用
    /// 
    /// 当创建交易时调用此方法更新预算分配的使用金额
    pub async fn record_usage(
        db: &DbConn,
        allocation_serial_num: &str,
        amount: Decimal,
        _transaction_serial_num: &str,
    ) -> MijiResult<BudgetAllocationResponse> {
        let allocation = Self::get(db, allocation_serial_num).await?;

        // 1. 计算新的使用金额
        let new_used_amount = allocation.used_amount + amount;
        let new_remaining_amount = allocation.allocated_amount - new_used_amount;

        // 2. 检查是否超支
        if new_remaining_amount < Decimal::ZERO {
            if !allocation.allow_overspend {
                return Err(AppError::simple(
                    BusinessCode::InvalidParameter,
                    "预算不足，且不允许超支",
                ));
            }

            // 检查超支限额
            let overspend_amount = new_remaining_amount.abs();
            if let Some(limit_type) = &allocation.overspend_limit_type {
                match limit_type.as_str() {
                    "PERCENTAGE" => {
                        if let Some(limit_value) = allocation.overspend_limit_value {
                            let max_overspend =
                                allocation.allocated_amount * (limit_value / Decimal::from(100));
                            if overspend_amount > max_overspend {
                                return Err(AppError::simple(
                                    BusinessCode::InvalidParameter,
                                    format!(
                                        "超支超过限额 {}%",
                                        limit_value
                                    ),
                                ));
                            }
                        }
                    }
                    "FIXED_AMOUNT" => {
                        if let Some(limit_value) = allocation.overspend_limit_value {
                            if overspend_amount > limit_value {
                                return Err(AppError::simple(
                                    BusinessCode::InvalidParameter,
                                    format!(
                                        "超支超过限额 {}元",
                                        limit_value
                                    ),
                                ));
                            }
                        }
                    }
                    _ => {}
                }
            }
        }

        // 3. 更新分配记录
        let mut active_model: entity::budget_allocations::ActiveModel = allocation.clone().into();
        active_model.used_amount = Set(new_used_amount);
        active_model.remaining_amount = Set(new_remaining_amount);
        active_model.updated_at = Set(Some(DateUtils::local_now()));

        let updated = active_model.update(db).await?;

        // 4. 检查预警
        let usage_percentage = if allocation.allocated_amount > Decimal::ZERO {
            (new_used_amount / allocation.allocated_amount * Decimal::from(100))
                .round_dp(2)
        } else {
            Decimal::ZERO
        };

        // 5. 转换为响应DTO
        let response = Self::to_response(&updated, usage_percentage)?;

        Ok(response)
    }

    /// 检查是否可以消费指定金额
    pub async fn can_spend(
        db: &DbConn,
        allocation_serial_num: &str,
        amount: Decimal,
    ) -> MijiResult<(bool, Option<String>)> {
        let allocation = Self::get(db, allocation_serial_num).await?;

        let after_amount = allocation.used_amount + amount;
        let remaining = allocation.allocated_amount - after_amount;

        // 未超支，允许
        if remaining >= Decimal::ZERO {
            return Ok((true, None));
        }

        // 不允许超支
        if !allocation.allow_overspend {
            return Ok((false, Some("预算不足，且不允许超支".to_string())));
        }

        // 检查超支限额
        let overspend_amount = remaining.abs();

        if let Some(limit_type) = &allocation.overspend_limit_type {
            match limit_type.as_str() {
                "PERCENTAGE" => {
                    if let Some(limit_value) = allocation.overspend_limit_value {
                        let max_overspend =
                            allocation.allocated_amount * (limit_value / Decimal::from(100));
                        if overspend_amount > max_overspend {
                            return Ok((
                                false,
                                Some(format!("超支将超过限额 {}%", limit_value)),
                            ));
                        }
                    }
                }
                "FIXED_AMOUNT" => {
                    if let Some(limit_value) = allocation.overspend_limit_value {
                        if overspend_amount > limit_value {
                            return Ok((
                                false,
                                Some(format!("超支将超过限额 {}元", limit_value)),
                            ));
                        }
                    }
                }
                _ => {}
            }
        }

        Ok((true, None))
    }

    /// 检查预算预警
    pub async fn check_alerts(
        db: &DbConn,
        budget_serial_num: &str,
    ) -> MijiResult<Vec<BudgetAlertResponse>> {
        let allocations = Self::list_by_budget(db, budget_serial_num).await?;
        let mut alerts = Vec::new();

        for allocation in allocations {
            if !allocation.alert_enabled {
                continue;
            }

            let usage_percentage = if allocation.allocated_amount > Decimal::ZERO {
                (allocation.used_amount / allocation.allocated_amount * Decimal::from(100))
                    .round_dp(2)
            } else {
                continue;
            };

            // 检查是否达到预警阈值
            if usage_percentage.to_i32().unwrap_or(0) >= allocation.alert_threshold {
                let alert_type = if allocation.remaining_amount < Decimal::ZERO {
                    "EXCEEDED"
                } else {
                    "WARNING"
                };

                let member_name = if let Some(ref member_sn) = allocation.member_serial_num {
                    // TODO: 查询成员名称
                    member_sn.clone()
                } else {
                    "所有成员".to_string()
                };

                let category_name = if let Some(ref cat_sn) = allocation.category_serial_num {
                    // TODO: 查询分类名称
                    cat_sn.clone()
                } else {
                    "所有分类".to_string()
                };

                alerts.push(BudgetAlertResponse {
                    budget_serial_num: allocation.budget_serial_num.clone(),
                    budget_name: format!("{} - {}", member_name, category_name),
                    alert_type: alert_type.to_string(),
                    usage_percentage,
                    remaining_amount: allocation.remaining_amount,
                    message: format!(
                        "预算使用已达 {}%，剩余 {}元",
                        usage_percentage, allocation.remaining_amount
                    ),
                });
            }
        }

        Ok(alerts)
    }

    // === 辅助方法 ===

    /// 获取预算的总分配金额
    async fn get_total_allocated(db: &DbConn, budget_serial_num: &str) -> MijiResult<Decimal> {
        use sea_orm::sea_query::Expr;

        let result = entity::budget_allocations::Entity::find()
            .filter(entity::budget_allocations::Column::BudgetSerialNum.eq(budget_serial_num))
            .select_only()
            .column_as(
                Expr::col(entity::budget_allocations::Column::AllocatedAmount).sum(),
                "total",
            )
            .into_tuple::<Option<Decimal>>()
            .one(db)
            .await?;

        Ok(result.flatten().unwrap_or(Decimal::ZERO))
    }

    /// 检查是否存在重复分配
    async fn check_duplicate(
        db: &DbConn,
        budget_serial_num: &str,
        category_serial_num: Option<&str>,
        member_serial_num: Option<&str>,
    ) -> MijiResult<bool> {
        let mut condition = Condition::all()
            .add(entity::budget_allocations::Column::BudgetSerialNum.eq(budget_serial_num));

        match (category_serial_num, member_serial_num) {
            (Some(cat), Some(mem)) => {
                condition = condition
                    .add(entity::budget_allocations::Column::CategorySerialNum.eq(cat))
                    .add(entity::budget_allocations::Column::MemberSerialNum.eq(mem));
            }
            (Some(cat), None) => {
                condition = condition
                    .add(entity::budget_allocations::Column::CategorySerialNum.eq(cat))
                    .add(entity::budget_allocations::Column::MemberSerialNum.is_null());
            }
            (None, Some(mem)) => {
                condition = condition
                    .add(entity::budget_allocations::Column::CategorySerialNum.is_null())
                    .add(entity::budget_allocations::Column::MemberSerialNum.eq(mem));
            }
            (None, None) => {
                // 理论上不会到这里，因为create方法已经验证
                return Ok(false);
            }
        }

        let count = entity::budget_allocations::Entity::find()
            .filter(condition)
            .count(db)
            .await?;

        Ok(count > 0)
    }

    /// 转换为响应DTO
    fn to_response(
        allocation: &entity::budget_allocations::Model,
        usage_percentage: Decimal,
    ) -> MijiResult<BudgetAllocationResponse> {
        let is_exceeded = allocation.remaining_amount < Decimal::ZERO;
        let is_warning = usage_percentage.to_i32().unwrap_or(0) >= allocation.alert_threshold;

        // 计算是否还能继续超支
        let can_overspend_more = if allocation.allow_overspend {
            if let Some(limit_type) = &allocation.overspend_limit_type {
                match limit_type.as_str() {
                    "PERCENTAGE" => {
                        if let Some(limit_value) = allocation.overspend_limit_value {
                            let max_overspend =
                                allocation.allocated_amount * (limit_value / Decimal::from(100));
                            let current_overspend = allocation.remaining_amount.abs();
                            current_overspend < max_overspend
                        } else {
                            true
                        }
                    }
                    "FIXED_AMOUNT" => {
                        if let Some(limit_value) = allocation.overspend_limit_value {
                            let current_overspend = allocation.remaining_amount.abs();
                            current_overspend < limit_value
                        } else {
                            true
                        }
                    }
                    _ => true,
                }
            } else {
                true
            }
        } else {
            false
        };

        Ok(BudgetAllocationResponse {
            serial_num: allocation.serial_num.clone(),
            budget_serial_num: allocation.budget_serial_num.clone(),
            category_serial_num: allocation.category_serial_num.clone(),
            category_name: None, // TODO: 查询分类名称
            member_serial_num: allocation.member_serial_num.clone(),
            member_name: None, // TODO: 查询成员名称
            allocated_amount: allocation.allocated_amount,
            used_amount: allocation.used_amount,
            remaining_amount: allocation.remaining_amount,
            usage_percentage,
            percentage: allocation.percentage,
            is_exceeded,
            allocation_type: allocation.allocation_type.clone(),
            rule_config: allocation.rule_config.clone(),
            allow_overspend: allocation.allow_overspend,
            overspend_limit_type: allocation.overspend_limit_type.clone(),
            overspend_limit_value: allocation.overspend_limit_value,
            can_overspend_more,
            alert_enabled: allocation.alert_enabled,
            alert_threshold: allocation.alert_threshold,
            alert_config: allocation.alert_config.clone(),
            is_warning,
            priority: allocation.priority,
            is_mandatory: allocation.is_mandatory,
            status: allocation.status.clone(),
            notes: allocation.notes.clone(),
            created_at: allocation.created_at.to_string(),
            updated_at: allocation.updated_at.map(|t| t.to_string()),
        })
    }
}
