use common::{
    BusinessCode,
    crud::service::{CrudConverter, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{DateRange, Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};

use sea_orm::{
    ActiveModelTrait,
    ActiveValue::Set,
    ColumnTrait, Condition, DatabaseConnection, EntityTrait, IntoActiveModel, PaginatorTrait,
    QueryFilter, QueryOrder, QuerySelect, SelectTwo,
    prelude::Decimal,
    sea_query::{Expr, Func, SimpleExpr},
};
use serde::{Deserialize, Serialize};

use std::sync::Arc;
use std::{collections::HashMap, str::FromStr};
use validator::Validate;
use tracing::info;

use crate::{
    dto::account::{AccountBalanceSummary, CreateAccountRequest, UpdateAccountRequest},
    services::account_hooks::NoOpHooks,
};

/// 账户过滤器
#[derive(Debug, Validate, Deserialize)]
pub struct AccountFilter {
    pub name: Option<String>,
    pub r#type: Option<String>,
    pub currency: Option<String>,
    pub is_shared: Option<bool>,
    pub owner_id: Option<String>,
    pub is_active: Option<bool>,
    pub created_at_range: Option<DateRange>,
    pub updated_at_range: Option<DateRange>,
}

/// 包含完整关联信息的账户数据结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountWithRelations {
    pub account: entity::account::Model,
    pub currency: entity::currency::Model,
    pub owner: Option<entity::family_member::Model>,
}

impl Filter<entity::account::Entity> for AccountFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();

        if let Some(name) = &self.name {
            condition = condition.add(entity::account::Column::Name.eq(name));
        }
        if let Some(r#type) = &self.r#type {
            condition = condition.add(entity::account::Column::Type.eq(r#type));
        }
        if let Some(currency) = &self.currency {
            condition = condition.add(entity::account::Column::Currency.eq(currency));
        }
        if let Some(is_shared) = self.is_shared {
            condition = condition.add(entity::account::Column::IsShared.eq(is_shared as i32));
        }
        if let Some(owner_id) = &self.owner_id {
            condition = condition.add(entity::account::Column::OwnerId.eq(owner_id));
        }
        if let Some(is_active) = self.is_active {
            condition = condition.add(entity::account::Column::IsActive.eq(is_active as i32));
        }
        if let Some(created_range) = &self.created_at_range {
            if let Some(start) = &created_range.start {
                condition = condition.add(entity::account::Column::CreatedAt.gte(start.clone()));
            }
            if let Some(end) = &created_range.end {
                condition = condition.add(entity::account::Column::CreatedAt.lte(end.clone()));
            }
        }
        if let Some(updated_range) = &self.updated_at_range {
            if let Some(start) = &updated_range.start {
                condition = condition.add(entity::account::Column::UpdatedAt.gte(start.clone()));
            }
            if let Some(end) = &updated_range.end {
                condition = condition.add(entity::account::Column::UpdatedAt.lte(end.clone()));
            }
        }
        condition
    }
}

/// 账户转换器
#[derive(Debug)]
pub struct AccountConverter;

impl CrudConverter<entity::account::Entity, CreateAccountRequest, UpdateAccountRequest>
    for AccountConverter
{
    fn create_to_active_model(
        &self,
        data: CreateAccountRequest,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::account::Model,
        data: UpdateAccountRequest,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data)
            .map(|mut active_model| {
                // 保留主键和创建时间等不可变字段
                active_model.serial_num = Set(model.serial_num.clone());
                active_model.created_at = Set(model.created_at.clone());

                // 设置更新时间
                active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));

                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::account::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "accounts"
    }
}

/// 账户服务类型别名
pub type BaseAccountService = GenericCrudService<
    entity::account::Entity,
    AccountFilter,
    CreateAccountRequest,
    UpdateAccountRequest,
    AccountConverter,
    NoOpHooks,
>;

pub struct AccountService {
    base_service: BaseAccountService,
}

impl AccountService {
    pub fn new(
        converter: AccountConverter,
        hooks: NoOpHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        let base_service = BaseAccountService::new(converter, hooks, logger);
        Self { base_service }
    }

    /// 获取基础服务引用
    pub fn base(&self) -> &BaseAccountService {
        &self.base_service
    }

    /// 获取账户详情（带货币信息）
    pub async fn get_account_with_currency(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<(entity::account::Model, entity::currency::Model)> {
        entity::account::Entity::find_by_id(id)
            .find_also_related(entity::currency::Entity)
            .one(db)
            .await
            .map_err(AppError::from)?
            .and_then(|(account, currency)| currency.map(|c| (account, c)))
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    "Account not found or currency missing",
                )
            })
    }

    /// 获取账户详情（带完整关联信息：货币和所有者）
    pub async fn get_account_with_relations(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<(
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    )> {
        // 首先获取账户和货币信息
        let (account, currency) = self
            .get_account_with_currency(db, serial_num.clone())
            .await?;

        // 如果有 owner_id，获取所有者信息
        let owner = if let Some(owner_id) = &account.owner_id {
            entity::family_member::Entity::find_by_id(owner_id.clone())
                .one(db)
                .await?
        } else {
            None
        };

        Ok((account, currency, owner))
    }

    /// 使用自定义查询获取账户和所有关联信息（更高效的方法）
    pub async fn get_account_with_relations_optimized(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<(
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    )> {
        let result = entity::account::Entity::find_by_id(serial_num)
            .find_also_related(entity::currency::Entity)
            .find_also_related(entity::family_member::Entity)
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Account not found"))?;

        let (account, currency, owner) = result;
        let currency = currency.ok_or_else(|| {
            AppError::simple(BusinessCode::NotFound, "Currency information missing")
        })?;

        Ok((account, currency, owner))
    }

    /// 分页查询账户列表（带完整关联信息）
    pub async fn list_accounts_paged_with_relations(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<
        PagedResult<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )>,
    > {
        // 验证查询参数
        query.validate().map_err(AppError::from_validation_errors)?;

        // 构建查询 - 先获取基础的 account + currency 信息
        let mut query_builder = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.filter.to_condition());

        // 应用排序
        query_builder = Self::apply_sort_to_select_two(
            query_builder,
            &query.sort_options.sort_by,
            query.sort_options.desc,
        );

        let (rows, total_count, total_pages) = Self::paginate_query(
            query_builder,
            db,
            query.page_size as u64,
            query.current_page as u64,
            // 过滤无货币的记录（可选过滤逻辑）
            |(account, currency)| currency.map(|c| (account, c)),
        )
        .await?;

        Ok(PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

    /// 分页查询账户列表（带货币信息）
    pub async fn list_accounts_paged_with_currency(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<PagedResult<(entity::account::Model, entity::currency::Model)>> {
        // 验证查询参数
        query.validate().map_err(AppError::from_validation_errors)?;

        let mut query_builder = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.filter.to_condition());

        // 应用排序
        query_builder = Self::apply_sort_to_select_two(
            query_builder,
            &query.sort_options.sort_by,
            query.sort_options.desc,
        );

        let (rows_with_currency, total_count, total_pages) = Self::paginate_query(
            query_builder,
            db,
            query.page_size as u64,
            query.current_page as u64,
            // 强制过滤无货币的记录（核心差异点）
            |(account, currency)| currency.map(|c| (account, c)),
        )
        .await?;

        let rows: Vec<_> = rows_with_currency
            .into_iter()
            .map(|(a, c, _)| (a, c))
            .collect();

        Ok(PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

    pub async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        query: AccountFilter,
    ) -> MijiResult<
        PagedResult<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )>,
    > {
        query.validate().map_err(AppError::from_validation_errors)?;

        let mut query_builder = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.to_condition());

        query_builder = Self::apply_sort_to_select_two(query_builder, &None, true);

        let rows_with_currency = query_builder.all(db).await.map_err(AppError::from)?;

        let owner_ids: Vec<String> = rows_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.as_ref())
            .cloned()
            .collect();
        let owners_map = Self::batch_fetch_owners(db, &owner_ids).await?;

        let assemble_row = Self::assemble_account_row(&owners_map);
        let rows: Vec<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )> = rows_with_currency
            .into_iter()
            .filter_map(|row| row.1.map(|currency| assemble_row((row.0, currency))))
            .collect();

        let total_count = rows.len();
        // 构造 PagedResult（无分页时，当前页为 1，每页大小为总记录数，总页数为 1）
        Ok(PagedResult {
            rows,
            total_count,
            current_page: 1,
            page_size: total_count,
            total_pages: 1,
        })
    }

    pub async fn update_account_active(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        is_active: bool,
    ) -> MijiResult<(
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    )> {
        let account = entity::account::Entity::find_by_id(serial_num.clone())
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    format!("Account with SerialNum {}", serial_num.clone()),
                )
            })?;

        let mut active_model = account.into_active_model();
        active_model.is_active = Set(is_active as i32);
        active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));

        active_model.update(db).await.map_err(AppError::from)?;

        let (updated_account, currency, owner) =
            entity::account::Entity::find_by_id(serial_num.clone())
                .find_also_related(entity::currency::Entity) // 预加载货币
                .find_also_related(entity::family_member::Entity) // 预加载家庭成员
                .one(db)
                .await?
                .ok_or_else(|| {
                    AppError::simple(
                        BusinessCode::NotFound,
                        format!("Account with ID {serial_num} not found after update"),
                    )
                })?;
        let currency = currency.ok_or_else(|| {
            AppError::simple(BusinessCode::NotFound, "Currency not found after update")
        })?;
        Ok((updated_account, currency, owner))
    }

    /// 通用批量查询家庭成员并构建映射
    async fn batch_fetch_owners(
        db: &DatabaseConnection,
        owner_ids: &[String],
    ) -> MijiResult<HashMap<String, entity::family_member::Model>> {
        if owner_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let owners = entity::family_member::Entity::find()
            .filter(entity::family_member::Column::SerialNum.is_in(owner_ids))
            .all(db)
            .await
            .map_err(AppError::from)?;

        Ok(owners
            .into_iter()
            .map(|owner| (owner.serial_num.clone(), owner))
            .collect())
    }

    /// 结果组装闭包
    fn assemble_account_row(
        owners_map: &HashMap<String, entity::family_member::Model>,
    ) -> impl Fn(
        (entity::account::Model, entity::currency::Model),
    ) -> (
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    ) {
        move |(account, currency)| {
            let owner = account
                .owner_id
                .as_ref()
                .and_then(|id| owners_map.get(id))
                .cloned();
            (account, currency, owner)
        }
    }

    /// 通用分页查询处理器
    async fn paginate_query<F>(
        query_builder: SelectTwo<entity::account::Entity, entity::currency::Entity>,
        db: &DatabaseConnection,
        page_size: u64,
        current_page: u64,
        filter_fn: F,
    ) -> MijiResult<(
        Vec<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )>,
        usize,
        usize,
    )>
    where
        F: Fn(
                (entity::account::Model, Option<entity::currency::Model>),
            ) -> Option<(entity::account::Model, entity::currency::Model)>
            + Clone,
    {
        let total_count = query_builder
            .clone()
            .count(db)
            .await
            .map_err(AppError::from)? as usize;
        let total_pages = total_count.div_ceil(page_size as usize);
        let offset = (current_page.saturating_sub(1)).saturating_mul(page_size);

        let rows_with_currency = query_builder
            .clone()
            .offset(offset)
            .limit(page_size)
            .all(db)
            .await
            .map_err(AppError::from)?;

        let owner_ids: Vec<String> = rows_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.clone())
            .collect();
        let owners_map = Self::batch_fetch_owners(db, &owner_ids).await?;

        let assemble_row = Self::assemble_account_row(&owners_map);
        let rows = rows_with_currency
            .into_iter()
            .filter_map(|row| filter_fn(row).map(&assemble_row))
            .collect();

        Ok((rows, total_count, total_pages))
    }

    pub async fn total_assets(&self, db: &DatabaseConnection) -> MijiResult<AccountBalanceSummary> {
        // 银行和储蓄
        let bank_savings_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).is_in(vec!["Savings", "Bank"]),
            Expr::col(entity::account::Column::Balance),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 现金
        let cash_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).eq("Cash"),
            Expr::col(entity::account::Column::Balance),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 信用卡（取绝对值）
        let credit_card_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).eq("CreditCard"),
            SimpleExpr::FunctionCall(Func::abs(Expr::col(entity::account::Column::Balance))),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 投资
        let investment_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).eq("Investment"),
            Expr::col(entity::account::Column::Balance),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 支付宝
        let alipay_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).eq("Alipay"),
            Expr::col(entity::account::Column::Balance),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 微信
        let wechat_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).eq("WeChat"),
            Expr::col(entity::account::Column::Balance),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 云闪付
        let cloud_quick_pass_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).eq("CloudQuickPass"),
            Expr::col(entity::account::Column::Balance),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 其他
        let other_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).eq("Other"),
            Expr::col(entity::account::Column::Balance),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 调整净资产（信用卡为负数）
        let adjusted_net_worth_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).eq("CreditCard"),
            Expr::val(-1).mul(Expr::col(entity::account::Column::Balance)),
        )
        .finally(Expr::col(entity::account::Column::Balance))
        .into();

        // 总资产（排除信用卡）
        let total_assets_case: SimpleExpr = Expr::case(
            Expr::col(entity::account::Column::Type).ne("CreditCard"),
            Expr::col(entity::account::Column::Balance),
        )
        .finally(Expr::val(Decimal::ZERO))
        .into();

        // 执行查询
        let result = entity::account::Entity::find()
            .select_only()
            .column_as(
                Expr::sum(Expr::expr(bank_savings_case)),
                "bank_savings_balance",
            )
            .column_as(Expr::sum(Expr::expr(cash_case)), "cash_balance")
            .column_as(
                Expr::sum(Expr::expr(credit_card_case)),
                "credit_card_balance",
            )
            .column_as(Expr::sum(Expr::expr(investment_case)), "investment_balance")
            .column_as(Expr::sum(Expr::expr(alipay_case)), "alipay_balance")
            .column_as(Expr::sum(Expr::expr(wechat_case)), "wechat_balance")
            .column_as(
                Expr::sum(Expr::expr(cloud_quick_pass_case)),
                "cloud_quick_pass_balance",
            )
            .column_as(Expr::sum(Expr::expr(other_case)), "other_balance")
            .column_as(
                Expr::sum(Expr::col(entity::account::Column::Balance)),
                "total_balance",
            )
            .column_as(
                Expr::sum(Expr::expr(adjusted_net_worth_case)),
                "adjusted_net_worth",
            )
            .column_as(Expr::sum(Expr::expr(total_assets_case)), "total_assets")
            .filter(entity::account::Column::IsActive.eq(1))
            .into_model::<AccountBalanceSummary>()
            .one(db)
            .await?
            .unwrap_or_default();

        Ok(result)
    }

    /// 自定义排序方法处理 SelectTwo 类型
    fn apply_sort_to_select_two(
        query_builder: SelectTwo<entity::account::Entity, entity::currency::Entity>,
        sort_by: &Option<String>,
        desc: bool,
    ) -> SelectTwo<entity::account::Entity, entity::currency::Entity> {
        if let Some(sort_by) = sort_by {
            // 尝试解析为账户字段
            if let Ok(column) = entity::account::Column::from_str(sort_by) {
                return if desc {
                    query_builder.order_by_desc(column)
                } else {
                    query_builder.order_by_asc(column)
                };
            }

            // 尝试解析为货币字段 (格式: currency.field)
            if let Some(("currency", field)) = sort_by.split_once('.') {
                if let Ok(column) = entity::currency::Column::from_str(field) {
                    return if desc {
                        query_builder.order_by_desc(column)
                    } else {
                        query_builder.order_by_asc(column)
                    };
                } else {
                    info!("currency query failed");
                }
            }
        }
        query_builder
    }
}

// ------------------------------ 服务实例获取 ------------------------------
/// 获取账户服务实例
pub fn get_account_service() -> AccountService {
    AccountService::new(
        AccountConverter,
        NoOpHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
