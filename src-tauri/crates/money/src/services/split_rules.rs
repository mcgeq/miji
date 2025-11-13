use common::{
    crud::service::{CrudConverter, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    log::logger::NoopLogger,
    paginations::{EmptyFilter, PagedResult},
};
use entity::localize::LocalizeModel;
use sea_orm::{
    ActiveValue, ColumnTrait, Condition, DbConn, EntityTrait, Order, PaginatorTrait, QueryFilter,
    QueryOrder, QuerySelect,
    prelude::{Decimal, async_trait::async_trait},
};
use serde_json::Value as JsonValue;

use crate::dto::split_rules::{
    SplitRuleCreate, SplitRuleQuery, SplitRuleResponse, SplitRuleUpdate,
};
use crate::services::split_rules_hooks::SplitRulesHooks;

pub type SplitRulesFilter = EmptyFilter;

#[derive(Debug)]
pub struct SplitRulesConverter;

impl CrudConverter<entity::split_rules::Entity, SplitRuleCreate, SplitRuleUpdate>
    for SplitRulesConverter
{
    fn create_to_active_model(
        &self,
        data: SplitRuleCreate,
    ) -> MijiResult<entity::split_rules::ActiveModel> {
        entity::split_rules::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::split_rules::Model,
        data: SplitRuleUpdate,
    ) -> MijiResult<entity::split_rules::ActiveModel> {
        let mut active_model = entity::split_rules::ActiveModel {
            serial_num: ActiveValue::Set(model.serial_num.clone()),
            family_ledger_serial_num: ActiveValue::Set(model.family_ledger_serial_num.clone()),
            created_by: ActiveValue::Set(model.created_by.clone()),
            created_at: ActiveValue::Set(model.created_at),
            ..Default::default()
        };

        data.apply_to_model(&mut active_model);
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::split_rules::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "split_rules"
    }
}

#[async_trait]
impl LocalizableConverter<entity::split_rules::Model> for SplitRulesConverter {
    async fn model_with_local(
        &self,
        model: entity::split_rules::Model,
    ) -> MijiResult<entity::split_rules::Model> {
        Ok(model.to_local())
    }
}

pub struct SplitRulesService {
    inner: GenericCrudService<
        entity::split_rules::Entity,
        SplitRulesFilter,
        SplitRuleCreate,
        SplitRuleUpdate,
        SplitRulesConverter,
        SplitRulesHooks,
    >,
}

impl SplitRulesService {
    pub fn new(
        converter: SplitRulesConverter,
        hooks: SplitRulesHooks,
        logger: std::sync::Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for SplitRulesService {
    type Target = GenericCrudService<
        entity::split_rules::Entity,
        SplitRulesFilter,
        SplitRuleCreate,
        SplitRuleUpdate,
        SplitRulesConverter,
        SplitRulesHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl Default for SplitRulesService {
    fn default() -> Self {
        use std::sync::Arc;
        Self::new(SplitRulesConverter, SplitRulesHooks, Arc::new(NoopLogger))
    }
}

impl SplitRulesService {
    /// 创建分摊规则
    pub async fn create_rule(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        data: SplitRuleCreate,
    ) -> MijiResult<SplitRuleResponse> {
        let mut active_model = SplitRulesConverter.create_to_active_model(data)?;
        active_model.family_ledger_serial_num =
            ActiveValue::Set(family_ledger_serial_num.to_string());

        let model = entity::split_rules::Entity::insert(active_model)
            .exec_with_returning(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(SplitRuleResponse::from(model))
    }

    /// 根据ID更新分摊规则
    pub async fn update_by_id(
        &self,
        db: &DbConn,
        rule_serial_num: &str,
        data: SplitRuleUpdate,
    ) -> MijiResult<SplitRuleResponse> {
        let existing_model = entity::split_rules::Entity::find_by_id(rule_serial_num)
            .one(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "分摊规则不存在"))?;

        let active_model = SplitRulesConverter.update_to_active_model(existing_model, data)?;

        let updated_model = entity::split_rules::Entity::update(active_model)
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(SplitRuleResponse::from(updated_model))
    }

    /// 根据ID删除分摊规则
    pub async fn delete_by_id(&self, db: &DbConn, rule_serial_num: &str) -> MijiResult<()> {
        let result = entity::split_rules::Entity::delete_by_id(rule_serial_num)
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        if result.rows_affected == 0 {
            return Err(AppError::simple(
                common::BusinessCode::NotFound,
                "分摊规则不存在",
            ));
        }

        Ok(())
    }

    /// 根据家庭账本ID查询分摊规则
    pub async fn find_by_family_ledger(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<Vec<SplitRuleResponse>> {
        self.find_by_family_ledger_with_query(
            db,
            family_ledger_serial_num,
            SplitRuleQuery::default(),
        )
        .await
        .map(|paged| paged.rows)
    }

    /// 根据家庭账本ID和查询条件查询分摊规则
    pub async fn find_by_family_ledger_with_query(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        query: SplitRuleQuery,
    ) -> MijiResult<PagedResult<SplitRuleResponse>> {
        let mut select = entity::split_rules::Entity::find().filter(
            entity::split_rules::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num),
        );

        // 应用查询条件
        if let Some(rule_type) = &query.rule_type {
            select = select.filter(entity::split_rules::Column::RuleType.eq(rule_type));
        }

        if let Some(is_template) = query.is_template {
            select = select.filter(entity::split_rules::Column::IsTemplate.eq(is_template));
        }

        if let Some(is_active) = query.is_active {
            select = select.filter(entity::split_rules::Column::IsActive.eq(is_active));
        }

        if let Some(category) = &query.category {
            select = select.filter(entity::split_rules::Column::Category.eq(category));
        }

        // 排序：优先级降序，创建时间降序
        select = select
            .order_by(entity::split_rules::Column::Priority, Order::Desc)
            .order_by(entity::split_rules::Column::CreatedAt, Order::Desc);

        let page = query.page.unwrap_or(1);
        let page_size = query.page_size.unwrap_or(20);

        // 简化分页实现
        let offset = (page - 1) * page_size;
        let models = select
            .limit(page_size)
            .offset(offset)
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        let total_count = entity::split_rules::Entity::find()
            .filter(entity::split_rules::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
            .count(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })? as u64;

        let responses: Vec<SplitRuleResponse> =
            models.into_iter().map(SplitRuleResponse::from).collect();

        Ok(PagedResult {
            rows: responses,
            total_count: total_count as usize,
            current_page: page as usize,
            page_size: page_size as usize,
            total_pages: total_count.div_ceil(page_size) as usize,
        })
    }

    /// 获取默认分摊规则
    pub async fn get_default_rule(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<Option<SplitRuleResponse>> {
        let rule = entity::split_rules::Entity::find()
            .filter(
                Condition::all()
                    .add(
                        entity::split_rules::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(entity::split_rules::Column::IsDefault.eq(true))
                    .add(entity::split_rules::Column::IsActive.eq(true)),
            )
            .one(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(rule.map(SplitRuleResponse::from))
    }

    /// 根据条件匹配分摊规则
    pub async fn match_rules(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        category: Option<&str>,
        sub_category: Option<&str>,
        amount: Decimal,
    ) -> MijiResult<Vec<SplitRuleResponse>> {
        let mut condition = Condition::all()
            .add(entity::split_rules::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
            .add(entity::split_rules::Column::IsActive.eq(true));

        // 匹配分类
        if let Some(cat) = category {
            condition = condition.add(
                Condition::any()
                    .add(entity::split_rules::Column::Category.eq(cat))
                    .add(entity::split_rules::Column::Category.is_null()),
            );
        }

        // 匹配子分类
        if let Some(sub_cat) = sub_category {
            condition = condition.add(
                Condition::any()
                    .add(entity::split_rules::Column::SubCategory.eq(sub_cat))
                    .add(entity::split_rules::Column::SubCategory.is_null()),
            );
        }

        // 匹配金额范围
        condition = condition.add(
            Condition::any()
                .add(entity::split_rules::Column::MinAmount.is_null())
                .add(entity::split_rules::Column::MinAmount.lte(amount)),
        );

        condition = condition.add(
            Condition::any()
                .add(entity::split_rules::Column::MaxAmount.is_null())
                .add(entity::split_rules::Column::MaxAmount.gte(amount)),
        );

        let rules = entity::split_rules::Entity::find()
            .filter(condition)
            .order_by(entity::split_rules::Column::Priority, Order::Desc)
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(rules.into_iter().map(SplitRuleResponse::from).collect())
    }

    /// 设置默认规则
    pub async fn set_default_rule(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        rule_serial_num: &str,
    ) -> MijiResult<()> {
        // 先取消所有默认规则
        entity::split_rules::Entity::update_many()
            .col_expr(
                entity::split_rules::Column::IsDefault,
                sea_orm::sea_query::Expr::value(false),
            )
            .filter(entity::split_rules::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 设置新的默认规则
        entity::split_rules::Entity::update_many()
            .col_expr(
                entity::split_rules::Column::IsDefault,
                sea_orm::sea_query::Expr::value(true),
            )
            .filter(
                Condition::all()
                    .add(
                        entity::split_rules::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(entity::split_rules::Column::SerialNum.eq(rule_serial_num)),
            )
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(())
    }

    /// 复制规则为模板
    pub async fn copy_as_template(
        &self,
        db: &DbConn,
        rule_serial_num: &str,
        template_name: &str,
    ) -> MijiResult<SplitRuleResponse> {
        let original_rule = entity::split_rules::Entity::find_by_id(rule_serial_num)
            .one(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "分摊规则不存在"))?;

        let template_create = SplitRuleCreate {
            name: template_name.to_string(),
            description: Some(format!("基于规则 {} 创建的模板", original_rule.name)),
            rule_type: original_rule.rule_type,
            rule_config: original_rule.rule_config,
            participant_members: original_rule.participant_members,
            is_template: Some(true),
            is_default: Some(false),
            category: None, // 模板不绑定特定分类
            sub_category: None,
            min_amount: None,
            max_amount: None,
            tags: original_rule.tags,
            priority: Some(0),
            is_active: Some(true),
        };

        let mut active_model = SplitRulesConverter.create_to_active_model(template_create)?;
        active_model.family_ledger_serial_num =
            ActiveValue::Set(original_rule.family_ledger_serial_num);
        active_model.created_by = ActiveValue::Set(original_rule.created_by);

        let template = entity::split_rules::Entity::insert(active_model)
            .exec_with_returning(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(SplitRuleResponse::from(template))
    }

    /// 验证规则配置
    pub fn validate_rule_config(
        &self,
        rule_type: &str,
        rule_config: &JsonValue,
        _participant_members: &JsonValue,
    ) -> MijiResult<()> {
        match rule_type {
            "Equal" => {
                // 均摊不需要特殊配置
                Ok(())
            }
            "Percentage" => {
                // 验证百分比总和为100
                if let Some(percentages) =
                    rule_config.get("percentages").and_then(|p| p.as_object())
                {
                    let total: f64 = percentages.values().filter_map(|v| v.as_f64()).sum();

                    if (total - 100.0).abs() > 0.01 {
                        return Err(AppError::simple(
                            common::BusinessCode::ValidationError,
                            "百分比总和必须等于100%",
                        ));
                    }
                }
                Ok(())
            }
            "FixedAmount" => {
                // 验证固定金额配置
                if rule_config.get("amounts").is_none() {
                    return Err(AppError::simple(
                        common::BusinessCode::ValidationError,
                        "固定金额规则必须配置金额",
                    ));
                }
                Ok(())
            }
            "Weighted" => {
                // 验证权重配置
                if rule_config.get("weights").is_none() {
                    return Err(AppError::simple(
                        common::BusinessCode::ValidationError,
                        "权重规则必须配置权重",
                    ));
                }
                Ok(())
            }
            _ => Err(AppError::simple(
                common::BusinessCode::ValidationError,
                "不支持的分摊规则类型",
            )),
        }
    }
}
