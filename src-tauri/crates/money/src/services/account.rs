use common::{
    BusinessCode,
    crud::service::{CrudConverter, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{DateRange, Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use entity::account::Column as AColumn;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, Condition, DatabaseConnection, EntityOrSelect,
    EntityTrait, IntoActiveModel, PaginatorTrait, QueryFilter, QueryOrder, QuerySelect, SelectTwo,
};
use serde::{Deserialize, Serialize};
use std::str::FromStr;
use std::sync::Arc;
use validator::Validate;

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
            condition = condition.add(AColumn::Name.eq(name));
        }
        if let Some(r#type) = &self.r#type {
            condition = condition.add(AColumn::Type.eq(r#type));
        }
        if let Some(currency) = &self.currency {
            condition = condition.add(AColumn::Currency.eq(currency));
        }
        if let Some(is_shared) = self.is_shared {
            condition = condition.add(AColumn::IsShared.eq(is_shared as i32));
        }
        if let Some(owner_id) = &self.owner_id {
            condition = condition.add(AColumn::OwnerId.eq(owner_id));
        }
        if let Some(is_active) = self.is_active {
            condition = condition.add(AColumn::IsActive.eq(is_active as i32));
        }
        if let Some(created_range) = &self.created_at_range {
            if let Some(start) = &created_range.start {
                condition = condition.add(AColumn::CreatedAt.ge(start));
            }
            if let Some(end) = &created_range.end {
                condition = condition.add(AColumn::CreatedAt.le(end));
            }
        }
        if let Some(updated_range) = &self.updated_at_range {
            if let Some(start) = &updated_range.start {
                condition = condition.add(AColumn::UpdatedAt.ge(start));
            }
            if let Some(end) = &updated_range.end {
                condition = condition.add(AColumn::UpdatedAt.le(end));
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
                .await
                .map_err(AppError::from)
                .transpose()?
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
            query.page_size,
            query.current_page,
            // 过滤无货币的记录（可选过滤逻辑）
            |(account, currency)| currency.map(|_| (account, currency)),
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
            query.page_size,
            query.current_page,
            // 强制过滤无货币的记录（核心差异点）
            |(account, currency)| currency.map(|c| (account, c)),
        )
        .await?;

        Ok(PagedResult {
            rows: rows_with_currency,
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

        query_builder = Self::apply_sort_to_select_two(
            query_builder,
            &query.sort_options.sort_by,
            query.sort_options.desc,
        );

        let rows_with_currency = query_builder.all(db).await.map_err(AppError::from)?;

        let owner_ids: Vec<String> = rows_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.as_ref())
            .cloned()
            .collect();
        let owners_map = Self::batch_fetch_owners(db, &owner_ids).await?;

        let assemble_row = Self::assemble_account_row(&owners_map);
        let rows = rows_with_currency
            .into_iter()
            .filter_map(|row| row.1.map(|currency| assemble_row((row.0, currency))))
            .collect();

        // 构造 PagedResult（无分页时，当前页为 1，每页大小为总记录数，总页数为 1）
        Ok(PagedResult {
            rows,
            total_count: rows.len(),
            current_page: 1,
            page_size: rows.len(),
            total_pages: 1,
        })
    }

    pub async fn update_account_active(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        is_active: bool,
    ) -> MijiResult<
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    > {
        let mut account = entity::account::Entity::find_by_id(serial_num)
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    format!("Account with SerialNum {serial_num}"),
                )
            })?;

        let mut active_model = account.into_active_model();
        active_model.is_active = Set(is_active as i32);
        active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));

        active_model.update(db).await.map_err(AppError::from)?;

        let (updated_account, currency, owner) = entity::account::Entity::find_by_id(serial_num)
            .find_also_related(entity::currency::Entity) // 预加载货币
            .find_also_related(entity::family_member::Entity) // 预加载家庭成员
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    format!("Account with ID {} not found after update", account_id),
                )
            })?;
        Ok((updated_account, currency, owner))
    }

    /// 通用批量查询家庭成员并构建映射（优化点 1）
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

    /// 结果组装闭包（优化点 2）
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

    /// 通用分页查询处理器（优化点 3）
    async fn paginate_query<T, F>(
        mut query_builder: impl Into<
            SelectStatement<
                '_,
                T,
                NoFromClause,
                DefaultSelectExpression,
                NoDistinctClause,
                NoOrderClause,
                NoLimitClause,
                NoOffsetClause,
            >,
        >,
        db: &DatabaseConnection,
        page_size: u64,
        current_page: u64,
        filter_fn: F, // 可选：用于结果过滤的闭包
    ) -> MijiResult<(Vec<T>, usize, usize)>
    where
        T: Model + 'static,
        F: Fn((T, entity::currency::Model)) -> Option<(T, entity::currency::Model)> + Clone,
    {
        let query_builder = query_builder.into();
        let total_count = query_builder
            .clone()
            .count(db)
            .await
            .map_err(AppError::from)? as usize;
        let total_pages = total_count.div_ceil(page_size);
        let offset = (current_page.saturating_sub(1)).saturating_mul(page_size);

        // 获取分页数据（账户+货币）
        let rows_with_currency = query_builder
            .offset(offset as u64)
            .limit(page_size as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;

        // 提取并批量查询家庭成员
        let owner_ids: Vec<String> = rows_with_currency
            .into_iter()
            .filter_map(|(account, _)| account.owner_id)
            .collect();
        let owners_map = Self::batch_fetch_owners(db, &owner_ids).await?;

        // 组装最终结果（含过滤）
        let assemble_row = Self::assemble_account_row(&owners_map);
        let rows = rows_with_currency
            .into_iter()
            .filter_map(|row| {
                filter_fn(row).and_then(|filtered_row| Some(assemble_row(filtered_row)))
            })
            .collect();

        Ok((rows, total_count, total_pages))
    }

    pub async fn total_assets(db: &DatabaseConnection) -> MijiResult<AccountBalanceSummary> {
        // 构建 `CASE WHEN` 表达式（手动链式调用，避免宏问题）
        let bank_savings_case = Expr::case()
            .when(AColumn::r#Type.in_vec(vec![
                Value::String("Savings".to_string()),
                Value::String("Bank".to_string()),
            ]))
            .then(AColumn::Balance)
            .else_(Value::Decimal(Decimal::ZERO));

        let cash_case = Expr::case()
            .when(AColumn::r#Type.eq(Value::String("Cash".to_string())))
            .then(AColumn::Balance)
            .else_(Value::Decimal(Decimal::ZERO));

        let credit_card_case = Expr::case()
            .when(AColumn::r#Type.eq(Value::String("CreditCard".to_string())))
            .then(AColumn::Balance.abs())
            .else_(Value::Decimal(Decimal::ZERO));

        let investment_case = Expr::case()
            .when(AColumn::r#Type.eq(Value::String("Investment".to_string())))
            .then(AColumn::Balance)
            .else_(Value::Decimal(Decimal::ZERO));

        let alipay_case = Expr::case()
            .when(AColumn::r#Type.eq(Value::String("Alipay".to_string())))
            .then(AColumn::Balance)
            .else_(Value::Decimal(Decimal::ZERO));

        let wechat_case = Expr::case()
            .when(AColumn::r#Type.eq(Value::String("WeChat".to_string())))
            .then(AColumn::Balance)
            .else_(Value::Decimal(Decimal::ZERO));

        let cloud_quick_pass_case = Expr::case()
            .when(AColumn::r#Type.eq(Value::String("CloudQuickPass".to_string())))
            .then(AColumn::Balance)
            .else_(Value::Decimal(Decimal::ZERO));

        let other_case = Expr::case()
            .when(AColumn::r#Type.eq(Value::String("Other".to_string())))
            .then(AColumn::Balance)
            .else_(Value::Decimal(Decimal::ZERO));

        let adjusted_net_worth_case = Expr::case()
            .when(AColumn::r#Type.eq(Value::String("CreditCard".to_string())))
            .then(AColumn::Balance.neg())
            .else_(Column::Balance);

        let total_assets_case = Expr::case()
            .when(AColumn::r#Type.not_in(vec![Value::String("CreditCard".to_string())]))
            .then(AColumn::Balance)
            .else_(Value::Decimal(Decimal::ZERO));

        // 构建完整查询
        let query = AccountEntity
            .select([
                Expr::sum(bank_savings_case).alias("bank_savings_balance"),
                Expr::sum(cash_case).alias("cash_balance"),
                Expr::sum(credit_card_case).alias("credit_card_balance"),
                Expr::sum(investment_case).alias("investment_balance"),
                Expr::sum(alipay_case).alias("alipay_balance"),
                Expr::sum(wechat_case).alias("wechat_balance"),
                Expr::sum(cloud_quick_pass_case).alias("cloud_quick_pass_balance"),
                Expr::sum(other_case).alias("other_balance"),
                Expr::sum(Column::Balance).alias("total_balance"),
                Expr::sum(adjusted_net_worth_case).alias("adjusted_net_worth"),
                Expr::sum(total_assets_case).alias("total_assets"),
            ])
            .from(AccountEntity)
            .and_where(AColumn::IsActive.eq(1));

        // 执行查询并解析结果
        let result = query.one(db).await?;

        Ok(AccountBalanceSummary {
            bank_savings_balance: result.bank_savings_balance,
            cash_balance: result.cash_balance,
            credit_card_balance: result.credit_card_balance,
            investment_balance: result.investment_balance,
            alipay_balance: result.alipay_balance,
            wechat_balance: result.wechat_balance,
            cloud_quick_pass_balance: result.cloud_quick_pass_balance,
            other_balance: result.other_balance,
            total_balance: result.total_balance,
            adjusted_net_worth: result.adjusted_net_worth,
            total_assets: result.total_assets,
        })
    }

    /// 自定义排序方法处理 SelectTwo 类型
    fn apply_sort_to_select_two(
        query_builder: SelectTwo<entity::account::Entity, entity::currency::Entity>,
        sort_by: &Option<String>,
        desc: bool,
    ) -> SelectTwo<entity::account::Entity, entity::currency::Entity> {
        if let Some(sort_by) = sort_by {
            // 尝试解析为账户字段
            if let Ok(column) = AColumn::from_str(sort_by) {
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
