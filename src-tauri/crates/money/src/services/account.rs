use common::{
    BusinessCode,
    crud::service::{CrudConverter, CrudService, GenericCrudService, sanitize_input},
    error::{AppError, MijiResult},
    log::logger::{NoopLogger, OperationLogger},
    paginations::{DateRange, Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use once_cell::sync::Lazy;
use sea_orm::{
    ActiveValue::Set,
    ColumnTrait, Condition, DatabaseConnection, DbConn, EntityTrait, PaginatorTrait, QueryFilter,
    QueryOrder, QuerySelect, SelectTwo,
    sea_query::{Alias, Expr, ExprTrait, Func, SimpleExpr},
};
use serde::{Deserialize, Serialize};
use std::ops::Deref;
use std::sync::Arc;
use std::{collections::HashMap, str::FromStr};
use tracing::info;
use validator::Validate;

use crate::{
    dto::account::{
        AccountBalanceSummary, AccountCreate, AccountResponse, AccountType, AccountUpdate, AccountWithRelations,
    },
    services::{account_hooks::AccountHooks, family_member::FamilyMemberService},
};
use entity::{
    account::{Column as AccountColumn, Entity as AccountEntity, Model as AccountModel},
    currency::{Column as CurrencyColumn, Entity as CurrencyEntity, Model as CurrencyModel},
    family_member::Model as FamilyMemberModel,
    localize::LocalizeModel,
};

/// ---------------------------------------------
/// 常量定义
/// ---------------------------------------------
const BOOL_TRUE_I32: i32 = 1;
const BOOL_FALSE_I32: i32 = 0;

/// ---------------------------------------------
/// 配置部分
/// 账户类型配置，用于动态处理 total_assets
/// ---------------------------------------------
#[derive(Debug, Clone)]
struct AccountTypeConfig {
    struct_field: &'static str,
    condition: Condition,
    balance_expr: SimpleExpr,
    /// 是否包含在总资产中（不包含负债类账户）
    include_in_total_assets: bool,
    /// 是否使用绝对值
    use_abs: bool,
    /// 在调整后净值中是否为负向（如信用卡）
    negative_in_net_worth: bool,
}

// 辅助函数：为条件添加非虚拟账户过滤
fn add_non_virtual_condition(condition: Condition) -> Condition {
    Condition::all()
        .add(condition)
        .add(AccountColumn::IsVirtual.eq(false))
}

static ACCOUNT_TYPE_CONFIGS: Lazy<Vec<AccountTypeConfig>> = Lazy::new(|| {
    vec![
        AccountTypeConfig {
            struct_field: "bank_savings_balance",
            condition: add_non_virtual_condition(
                Condition::any()
                    .add(AccountColumn::Type.eq(AccountType::Savings.as_ref()))
                    .add(AccountColumn::Type.eq(AccountType::Bank.as_ref())),
            ),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
            use_abs: false,
            negative_in_net_worth: false,
        },
        AccountTypeConfig {
            struct_field: "cash_balance",
            condition: add_non_virtual_condition(
                Condition::all().add(AccountColumn::Type.eq(AccountType::Cash.as_ref())),
            ),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
            use_abs: false,
            negative_in_net_worth: false,
        },
        AccountTypeConfig {
            struct_field: "credit_card_balance",
            condition: add_non_virtual_condition(
                Condition::all().add(AccountColumn::Type.eq(AccountType::CreditCard.as_ref())),
            ),
            balance_expr: cast_decimal(SimpleExpr::FunctionCall(Func::abs(Expr::col(
                AccountColumn::Balance,
            )))),
            include_in_total_assets: false, // 信用卡是负债，不计入总资产
            use_abs: true,
            negative_in_net_worth: true, // 信用卡在净值中是负向的
        },
        AccountTypeConfig {
            struct_field: "investment_balance",
            condition: add_non_virtual_condition(
                Condition::all().add(AccountColumn::Type.eq(AccountType::Investment.as_ref())),
            ),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
            use_abs: false,
            negative_in_net_worth: false,
        },
        AccountTypeConfig {
            struct_field: "alipay_balance",
            condition: add_non_virtual_condition(
                Condition::all().add(AccountColumn::Type.eq(AccountType::Alipay.as_ref())),
            ),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
            use_abs: false,
            negative_in_net_worth: false,
        },
        AccountTypeConfig {
            struct_field: "wechat_balance",
            condition: add_non_virtual_condition(
                Condition::all().add(AccountColumn::Type.eq(AccountType::WeChat.as_ref())),
            ),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
            use_abs: false,
            negative_in_net_worth: false,
        },
        AccountTypeConfig {
            struct_field: "cloud_quick_pass_balance",
            condition: add_non_virtual_condition(
                Condition::all().add(AccountColumn::Type.eq(AccountType::CloudQuickPass.as_ref())),
            ),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
            use_abs: false,
            negative_in_net_worth: false,
        },
        AccountTypeConfig {
            struct_field: "other_balance",
            condition: add_non_virtual_condition(
                Condition::all().add(AccountColumn::Type.eq(AccountType::Other.as_ref())),
            ),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
            use_abs: false,
            negative_in_net_worth: false,
        },
    ]
});

/// ---------------------------------------------
/// 账户过滤器
/// ---------------------------------------------
#[derive(Debug, Validate, Deserialize)]
#[serde(rename_all = "camelCase")]
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

impl Filter<entity::account::Entity> for AccountFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();
        if let Some(name) = &self.name {
            condition = condition.add(AccountColumn::Name.eq(sanitize_input(name)));
        }
        if let Some(r#type) = &self.r#type {
            condition = condition.add(AccountColumn::Type.eq(sanitize_input(r#type)));
        }
        if let Some(currency) = &self.currency {
            condition = condition.add(AccountColumn::Currency.eq(sanitize_input(currency)));
        }
        if let Some(is_shared) = self.is_shared {
            let value = if is_shared {
                BOOL_TRUE_I32
            } else {
                BOOL_FALSE_I32
            };
            condition = condition.add(AccountColumn::IsShared.eq(value));
        }
        if let Some(owner_id) = &self.owner_id {
            condition = condition.add(AccountColumn::OwnerId.eq(sanitize_input(owner_id)));
        }
        if let Some(is_active) = self.is_active {
            let value = if is_active {
                BOOL_TRUE_I32
            } else {
                BOOL_FALSE_I32
            };
            condition = condition.add(AccountColumn::IsActive.eq(value));
        }
        if let Some(range) = &self.created_at_range {
            condition = condition.add(range.to_condition(AccountColumn::CreatedAt));
        }
        if let Some(updated_range) = &self.updated_at_range {
            condition = condition.add(updated_range.to_condition(AccountColumn::UpdatedAt));
        }
        condition
    }
}

/// ---------------------------------------------
/// 转换器
/// ---------------------------------------------
#[derive(Debug)]
pub struct AccountConverter;

impl CrudConverter<AccountEntity, AccountCreate, AccountUpdate> for AccountConverter {
    fn create_to_active_model(
        &self,
        data: AccountCreate,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: AccountModel,
        data: AccountUpdate,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = Set(model.serial_num.clone());
                active_model.created_at = Set(model.created_at);
                active_model.updated_at = Set(Some(DateUtils::local_now()));
                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &AccountModel) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "accounts"
    }
}

/// ---------------------------------------------
/// Account Service
/// 账户服务类型别名
/// ---------------------------------------------
pub type BaseAccountService = GenericCrudService<
    AccountEntity,
    AccountFilter,
    AccountCreate,
    AccountUpdate,
    AccountConverter,
    AccountHooks,
>;

pub struct AccountService {
    inner: BaseAccountService,
}

impl Default for AccountService {
    fn default() -> Self {
        Self::new(Some(Arc::new(common::log::logger::NoopLogger)))
    }
}

impl AccountService {
    pub fn new(logger: Option<Arc<dyn OperationLogger>>) -> Self {
        let lg = logger.unwrap_or_else(|| Arc::new(NoopLogger));
        Self {
            inner: GenericCrudService::new(AccountConverter, AccountHooks, lg.clone()),
        }
    }

    /// account type configs
    fn account_type_configs() -> &'static [AccountTypeConfig] {
        &ACCOUNT_TYPE_CONFIGS
    }
}

/// 实现 Deref，让 AccountService 可以自动解引用到 BaseAccountService
/// 这样可以直接调用 CrudService 的所有方法，无需手动转发
impl Deref for AccountService {
    type Target = BaseAccountService;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl AccountService {
    /// 批量加载账户的 owner (family_member) 信息
    /// 返回 owner_id -> FamilyMemberModel 的映射
    async fn batch_load_owners(
        db: &DatabaseConnection,
        accounts: &[(AccountModel, Option<CurrencyModel>)],
    ) -> MijiResult<HashMap<String, FamilyMemberModel>> {
        let owner_ids: Vec<String> = accounts
            .iter()
            .filter_map(|(account, _)| account.owner_id.clone())
            .map(|id| sanitize_input(&id))
            .collect();

        if owner_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let family_member_service = FamilyMemberService::default();
        family_member_service
            .family_member_batch_get(db, &owner_ids)
            .await
    }

    pub async fn get_account_with_relations(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<AccountWithRelations> {
        let result = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .find_also_related(entity::family_member::Entity)
            .filter(entity::account::Column::SerialNum.eq(serial_num))
            .one(db)
            .await?;
        let (account, currency_opt, owner_opt) =
            result.ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Account not found"))?;
        let cny = currency_opt.ok_or_else(|| {
            AppError::simple(
                BusinessCode::NotFound,
                "Currency not found for this account",
            )
        })?;

        Ok(AccountWithRelations {
            account: account.to_local(),
            currency: cny.to_local(),
            owner: owner_opt.map(|o| o.to_local()),
        })
    }

    async fn paginate_with_relations_base<T, F>(
        db: &DatabaseConnection,
        base_query: SelectTwo<AccountEntity, CurrencyEntity>,
        query: PagedQuery<AccountFilter>,
        transform: F,
    ) -> MijiResult<PagedResult<T>>
    where
        T: Send + Sync + Serialize,
        F: Fn((AccountModel, CurrencyModel, Option<FamilyMemberModel>)) -> T + Clone,
    {
        query.validate().map_err(AppError::from_validation_errors)?;
        let query_builder = Self::apply_sort_to_select_two(
            base_query.filter(query.filter.to_condition()),
            &query.sort_options.sort_by,
            query.sort_options.desc,
        );

        let total_count = query_builder
            .clone()
            .count(db)
            .await
            .map_err(AppError::from)? as usize;
        let total_pages = total_count.div_ceil(query.page_size);
        let offset = (query.current_page - 1) * query.page_size;

        let rows_with_currency = query_builder
            .offset(offset as u64)
            .limit(query.page_size as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;

        let owners_map = Self::batch_load_owners(db, &rows_with_currency).await?;

        let rows = rows_with_currency
            .into_iter()
            .filter_map(|(account, currency)| {
                currency.map(|c| {
                    let owner = account
                        .owner_id
                        .as_ref()
                        .and_then(|id| owners_map.get(id))
                        .cloned();
                    transform((account.to_local(), c.to_local(), owner))
                })
            })
            .collect();

        Ok(PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

    fn apply_sort_to_select_two(
        query_builder: SelectTwo<AccountEntity, CurrencyEntity>,
        sort_by: &Option<String>,
        desc: bool,
    ) -> SelectTwo<AccountEntity, CurrencyEntity> {
        let Some(sort_by) = sort_by else {
            return query_builder;
        };

        let sort_by = sanitize_input(sort_by);

        match AccountColumn::from_str(&sort_by) {
            Ok(column) => {
                if desc {
                    query_builder.order_by_desc(column)
                } else {
                    query_builder.order_by_asc(column)
                }
            }
            Err(_) => match sort_by.split_once('.') {
                Some(("currency", field)) => match CurrencyColumn::from_str(field) {
                    Ok(column) => {
                        if desc {
                            query_builder.order_by_desc(column)
                        } else {
                            query_builder.order_by_asc(column)
                        }
                    }
                    Err(_) => {
                        info!("Invalid sort field: {}", sort_by);
                        query_builder
                    }
                },
                _ => {
                    info!("Invalid sort field: {}", sort_by);
                    query_builder
                }
            },
        }
    }
}

impl AccountService {
    pub async fn account_create(
        &self,
        db: &DatabaseConnection,
        data: AccountCreate,
    ) -> MijiResult<AccountWithRelations> {
        let account = self.inner.create(db, data).await?;
        let account_with_relations = self
            .get_account_with_relations(db, account.serial_num.clone())
            .await?;
        Ok(account_with_relations)
    }

    pub async fn account_update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: AccountUpdate,
    ) -> MijiResult<AccountWithRelations> {
        info!("account_update {:?}", data);
        if let Some(new_initial) = data.initial_balance {
            let old_account = self.get_by_id(db, serial_num.clone()).await?;
            let old_initial = old_account.initial_balance;
            let old_balance = old_account.balance;

            let diff = new_initial - old_initial;
            let new_balance = old_balance + diff;
            if new_balance.is_sign_negative() {
                return Err(AppError::simple(
                    BusinessCode::MoneyInvalidAmount,
                    "账户余额不能为负数".to_string(),
                ));
            }
            update_account_columns(
                db,
                [serial_num.clone()],
                [
                    (entity::account::Column::Balance, Expr::value(new_balance)),
                    (
                        entity::account::Column::UpdatedAt,
                        Expr::value(Some(DateUtils::local_now())),
                    ),
                ],
            )
            .await?;
        }
        let model = self.update(db, serial_num.clone(), data).await?;
        self.get_account_with_relations(db, model.serial_num).await
    }

    pub async fn update_account_active(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        is_active: bool,
    ) -> MijiResult<AccountWithRelations> {
        let value = if is_active {
            BOOL_TRUE_I32
        } else {
            BOOL_FALSE_I32
        };
        update_account_columns(
            db,
            std::iter::once(serial_num.clone()),
            [
                (entity::account::Column::IsActive, Expr::value(value)),
                (
                    entity::account::Column::UpdatedAt,
                    Expr::value(Some(DateUtils::local_now())),
                ),
            ],
        )
        .await?;
        self.get_account_with_relations(db, serial_num).await
    }

    pub async fn list_accounts_paged_with_relations(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<PagedResult<AccountWithRelations>> {
        Self::paginate_with_relations_base(
            db,
            AccountEntity::find().find_also_related(CurrencyEntity),
            query,
            |(account, currency, owner)| AccountWithRelations {
                account: account.to_local(),
                currency: currency.to_local(),
                owner: owner.map(|v| v.to_local()),
            },
        )
        .await
    }

    pub async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        query: AccountFilter,
    ) -> MijiResult<PagedResult<AccountWithRelations>> {
        query.validate().map_err(AppError::from_validation_errors)?;
        let query_builder = Self::apply_sort_to_select_two(
            AccountEntity::find()
                .find_also_related(CurrencyEntity)
                .filter(query.to_condition()),
            &None,
            true,
        );

        let rows_with_currency = query_builder.all(db).await.map_err(AppError::from)?;

        let owners_map = Self::batch_load_owners(db, &rows_with_currency).await?;

        let rows_converted: Vec<AccountWithRelations> = rows_with_currency
            .into_iter()
            .filter_map(|(account, currency_opt)| {
                let currency = currency_opt?;
                let owner = account
                    .owner_id
                    .as_ref()
                    .and_then(|id| owners_map.get(id))
                    .cloned();
                Some(AccountWithRelations {
                    account: account.to_local(),
                    currency: currency.to_local(),
                    owner,
                })
            })
            .collect();

        let total_count = rows_converted.len();
        Ok(PagedResult {
            rows: rows_converted,
            total_count,
            current_page: 1,
            page_size: total_count,
            total_pages: 1,
        })
    }

    pub async fn total_assets(&self, db: &DatabaseConnection) -> MijiResult<AccountBalanceSummary> {
        let mut query = AccountEntity::find()
            .select_only()
            .filter(AccountColumn::IsActive.eq(BOOL_TRUE_I32))
            .filter(AccountColumn::IsVirtual.eq(false))
            .filter(AccountColumn::Type.ne(AccountType::CreditCard.to_string())); // 排除虚拟账户

        // 为每种账户类型创建求和表达式
        for config in Self::account_type_configs() {
            let expr = Expr::val(0.0).add(
                SimpleExpr::FunctionCall(Func::coalesce(vec![
                    SimpleExpr::FunctionCall(Func::sum(
                        Expr::case(config.condition.clone(), config.balance_expr.clone())
                            .finally(0.0)
                            .cast_as(Alias::new("DECIMAL(16,4)")),
                    )),
                    Expr::val(0.0).into(),
                ]))
                .cast_as(Alias::new("DECIMAL(16,4)")),
            );
            query = query.expr_as(expr, config.struct_field);
        }

        // 使用配置驱动的方式计算三个总计字段
        let total_balance_expr = Self::build_aggregate_expr(
            Self::account_type_configs(),
            |config| config.use_abs, // total_balance: 所有账户的绝对值之和
            |_| false,               // 所有账户都是正向加
        );

        let adjusted_net_worth_expr = Self::build_aggregate_expr(
            Self::account_type_configs(),
            |config| config.use_abs,               // 按配置使用绝对值
            |config| config.negative_in_net_worth, // 信用卡等负债类账户是负向的
        );

        // total_assets: 只包含非负债类账户，完全不包含信用卡等负债
        let total_assets_expr = Self::build_aggregate_expr_with_filter(
            Self::account_type_configs(),
            |config| config.include_in_total_assets, // 只处理 include_in_total_assets = true 的账户
            |_| false,                               // 不使用绝对值
            |_| false,                               // 全部使用加法
        );

        query = query
            .expr_as(total_balance_expr, "total_balance")
            .expr_as(adjusted_net_worth_expr, "adjusted_net_worth")
            .expr_as(total_assets_expr, "total_assets");

        let result = query
            .into_model::<AccountBalanceSummary>()
            .one(db)
            .await
            .map_err(AppError::from)?
            .unwrap_or_default();
        Ok(result)
    }

    /// 构建聚合表达式（用于 total_balance、adjusted_net_worth）
    ///
    /// # 参数
    /// - `configs`: 账户类型配置
    /// - `should_use_abs`: 判断是否对该配置使用绝对值的函数
    /// - `should_subtract`: 判断是否对该配置使用减法（而非加法）的函数
    fn build_aggregate_expr<F1, F2>(
        configs: &[AccountTypeConfig],
        should_use_abs: F1,
        should_subtract: F2,
    ) -> SimpleExpr
    where
        F1: Fn(&AccountTypeConfig) -> bool,
        F2: Fn(&AccountTypeConfig) -> bool,
    {
        Self::build_aggregate_expr_with_filter(
            configs,
            |_| true, // 不过滤，处理所有配置
            should_use_abs,
            should_subtract,
        )
    }

    /// 构建聚合表达式（带过滤功能，用于 total_assets）
    ///
    /// # 参数
    /// - `configs`: 账户类型配置
    /// - `should_include`: 判断是否应该包含该配置的函数（过滤器）
    /// - `should_use_abs`: 判断是否对该配置使用绝对值的函数
    /// - `should_subtract`: 判断是否对该配置使用减法（而非加法）的函数
    fn build_aggregate_expr_with_filter<F1, F2, F3>(
        configs: &[AccountTypeConfig],
        should_include: F1,
        should_use_abs: F2,
        should_subtract: F3,
    ) -> SimpleExpr
    where
        F1: Fn(&AccountTypeConfig) -> bool,
        F2: Fn(&AccountTypeConfig) -> bool,
        F3: Fn(&AccountTypeConfig) -> bool,
    {
        let mut expr: SimpleExpr = Expr::val(0.0).into();

        for config in configs {
            // 如果不应该包含这个配置，跳过
            if !should_include(config) {
                continue;
            }

            let sum_expr = if should_use_abs(config) {
                create_sum_expr_from_condition(config.condition.clone(), true)
            } else {
                create_sum_expr_from_condition(config.condition.clone(), false)
            };

            expr = if should_subtract(config) {
                expr.sub(sum_expr)
            } else {
                expr.add(sum_expr)
            };
        }

        expr.cast_as(Alias::new("DECIMAL(16, 4)"))
    }

    /// 将 Model 转换为 Response，并填充 Currency 详情
    pub async fn model_to_response(
        &self,
        db: &DatabaseConnection,
        model: entity::account::Model,
    ) -> MijiResult<AccountResponse> {
        use crate::dto::currency::CurrencyResponse;
        use entity::prelude::*;

        let mut response = AccountResponse::from(model.clone());
        
        // 查询 currency 详情
        if let Ok(Some(currency_model)) = Currency::find_by_id(&model.currency)
            .one(db)
            .await 
        {
            response.currency_detail = Some(CurrencyResponse::from(currency_model));
            tracing::debug!("Found currency detail for {}", model.currency);
        } else {
            tracing::warn!("Currency {} not found in database", model.currency);
        }
        
        Ok(response)
    }
    
    /// 批量转换 Models 到 Responses，并填充 Currency 详情（优化版：批量查询）
    pub async fn models_to_responses(
        &self,
        db: &DatabaseConnection,
        models: Vec<entity::account::Model>,
    ) -> MijiResult<Vec<AccountResponse>> {
        use crate::dto::currency::CurrencyResponse;
        use entity::prelude::*;
        use std::collections::{HashSet, HashMap};

        // 收集所有不同的 currency code
        let currency_codes: HashSet<String> = models
            .iter()
            .map(|m| m.currency.clone())
            .collect();
        
        tracing::debug!("Fetching {} unique currencies for accounts", currency_codes.len());
        
        // 批量查询所有 currency（避免 N+1 查询）
        let currencies = Currency::find()
            .filter(entity::currency::Column::Code.is_in(currency_codes))
            .all(db)
            .await?;
        
        // 构建 code -> Currency 映射
        let currency_map: HashMap<String, CurrencyResponse> = currencies
            .into_iter()
            .map(|c| (c.code.clone(), CurrencyResponse::from(c)))
            .collect();
        
        tracing::debug!("Found {} currencies in database", currency_map.len());
        
        // 转换
        let mut responses = Vec::with_capacity(models.len());
        for model in models {
            let mut response = AccountResponse::from(model.clone());
            response.currency_detail = currency_map.get(&model.currency).cloned();
            
            if response.currency_detail.is_none() {
                tracing::warn!("Currency {} not found", model.currency);
            }
            
            responses.push(response);
        }
        
        Ok(responses)
    }
}

/// ---------------------------------------------
/// 辅助函数
/// ---------------------------------------------
fn cast_decimal<T: Into<SimpleExpr>>(expr: T) -> SimpleExpr {
    expr.into().cast_as(Alias::new("DECIMAL(16,4)"))
}

/// 从条件创建 SUM 表达式（更通用的版本）
fn create_sum_expr_from_condition(condition: Condition, use_abs: bool) -> SimpleExpr {
    let balance_expr = if use_abs {
        SimpleExpr::FunctionCall(Func::abs(Expr::col(AccountColumn::Balance)))
    } else {
        Expr::col(AccountColumn::Balance).into()
    };

    SimpleExpr::FunctionCall(Func::coalesce(vec![
        SimpleExpr::FunctionCall(Func::sum(
            Expr::case(condition, balance_expr)
                .finally(0.0)
                .cast_as(Alias::new("DECIMAL(16,4)")),
        )),
        Expr::val(0.0).into(),
    ]))
    .cast_as(Alias::new("DECIMAL(16,4)"))
}

pub async fn update_account_columns<I, E>(
    db: &DbConn,
    serial_nums: impl IntoIterator<Item = String>,
    updates: I,
) -> MijiResult<u64>
where
    I: IntoIterator<Item = (entity::account::Column, E)>,
    E: Into<SimpleExpr>,
{
    let serial_nums: Vec<String> = serial_nums.into_iter().collect();

    if serial_nums.is_empty() {
        return Err(AppError::simple(
            BusinessCode::InvalidParameter,
            "serial_nums cannot be empty".to_string(),
        ));
    }

    let mut updater = entity::account::Entity::update_many()
        .filter(entity::account::Column::SerialNum.is_in(serial_nums.clone()));

    for (col, expr) in updates {
        updater = updater.col_expr(col, expr.into());
    }

    let result = updater.exec(db).await.map_err(AppError::from)?;
    if result.rows_affected == 0 {
        return Err(AppError::simple(
            BusinessCode::NotFound,
            format!("Not found with serial_num: {serial_nums:?}"),
        ));
    }
    Ok(result.rows_affected)
}
