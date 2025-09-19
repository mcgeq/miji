use common::{
    BusinessCode,
    crud::service::{
        CrudConverter, CrudService, GenericCrudService, TransactionalCrudService, sanitize_input,
    },
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
    prelude::async_trait::async_trait,
    sea_query::{Alias, Expr, ExprTrait, Func, SimpleExpr},
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::{collections::HashMap, str::FromStr};
use tracing::info;
use validator::Validate;

use crate::{
    dto::account::{
        AccountBalanceSummary, AccountCreate, AccountType, AccountUpdate, AccountWithRelations,
    },
    services::{account_hooks::AccountHooks, family_member::get_family_member_service},
};
use entity::{
    account::{Column as AccountColumn, Entity as AccountEntity, Model as AccountModel},
    currency::{Column as CurrencyColumn, Entity as CurrencyEntity, Model as CurrencyModel},
    family_member::Model as FamilyMemberModel,
    localize::LocalizeModel,
};

/// ---------------------------------------------
/// 配置部分
/// 账户类型配置，用于动态处理 total_assets
/// ---------------------------------------------
#[derive(Debug, Clone)]
struct AccountTypeConfig {
    struct_field: &'static str,
    condition: Condition,
    balance_expr: SimpleExpr,
    #[allow(dead_code)]
    include_in_total_assets: bool,
}

static ACCOUNT_TYPE_CONFIGS: Lazy<Vec<AccountTypeConfig>> = Lazy::new(|| {
    vec![
        AccountTypeConfig {
            struct_field: "bank_savings_balance",
            condition: Condition::any()
                .add(AccountColumn::Type.eq(AccountType::Savings.as_ref()))
                .add(AccountColumn::Type.eq(AccountType::Bank.as_ref())),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
        },
        AccountTypeConfig {
            struct_field: "cash_balance",
            condition: Condition::all().add(AccountColumn::Type.eq(AccountType::Cash.as_ref())),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
        },
        AccountTypeConfig {
            struct_field: "credit_card_balance",
            condition: Condition::all()
                .add(AccountColumn::Type.eq(AccountType::CreditCard.as_ref())),
            balance_expr: cast_decimal(SimpleExpr::FunctionCall(Func::abs(Expr::col(
                AccountColumn::Balance,
            )))),
            include_in_total_assets: true,
        },
        AccountTypeConfig {
            struct_field: "investment_balance",
            condition: Condition::all()
                .add(AccountColumn::Type.eq(AccountType::Investment.as_ref())),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
        },
        AccountTypeConfig {
            struct_field: "alipay_balance",
            condition: Condition::all().add(AccountColumn::Type.eq(AccountType::Alipay.as_ref())),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
        },
        AccountTypeConfig {
            struct_field: "wechat_balance",
            condition: Condition::all().add(AccountColumn::Type.eq(AccountType::WeChat.as_ref())),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
        },
        AccountTypeConfig {
            struct_field: "cloud_quick_pass_balance",
            condition: Condition::all()
                .add(AccountColumn::Type.eq(AccountType::CloudQuickPass.as_ref())),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
        },
        AccountTypeConfig {
            struct_field: "other_balance",
            condition: Condition::all().add(AccountColumn::Type.eq(AccountType::Other.as_ref())),
            balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
            include_in_total_assets: true,
        },
    ]
});

/// ---------------------------------------------
/// 账户过滤器
/// ---------------------------------------------
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
            condition = condition.add(AccountColumn::IsShared.eq(is_shared as i32));
        }
        if let Some(owner_id) = &self.owner_id {
            condition = condition.add(AccountColumn::OwnerId.eq(sanitize_input(owner_id)));
        }
        if let Some(is_active) = self.is_active {
            condition = condition.add(AccountColumn::IsActive.eq(is_active as i32));
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
/// 关联加载器 trait
/// ---------------------------------------------
#[async_trait]
pub trait RelationLoader<E: EntityTrait> {
    type Model: Send + Sync;
    async fn load(&self, db: &DbConn, model: &E::Model) -> MijiResult<Option<Self::Model>>;
    async fn batch_load(
        &self,
        db: &DbConn,
        ids: &[String],
    ) -> MijiResult<HashMap<String, Self::Model>>;
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

impl AccountService {
    pub fn get_service() -> Self {
        Self::new(None)
    }

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

#[async_trait]
impl CrudService<AccountEntity, AccountFilter, AccountCreate, AccountUpdate> for AccountService {
    async fn create(&self, db: &DbConn, data: AccountCreate) -> MijiResult<AccountModel> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(&self, db: &DbConn, id: String) -> MijiResult<AccountModel> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: AccountUpdate,
    ) -> MijiResult<AccountModel> {
        self.inner.update(db, serial_num, data).await
    }

    async fn delete(&self, db: &DbConn, serial_num: String) -> MijiResult<()> {
        self.inner.delete(db, serial_num).await
    }

    async fn list(&self, db: &DbConn) -> MijiResult<Vec<AccountModel>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DbConn,
        filter: AccountFilter,
    ) -> MijiResult<Vec<AccountModel>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DbConn,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<PagedResult<AccountModel>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DbConn,
        data: Vec<AccountCreate>,
    ) -> MijiResult<Vec<AccountModel>> {
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

    async fn count_with_filter(&self, db: &DbConn, filter: AccountFilter) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

#[async_trait]
impl TransactionalCrudService<AccountEntity, AccountFilter, AccountCreate, AccountUpdate>
    for AccountService
{
    async fn create_in_txn(&self, txn: &DbConn, data: AccountCreate) -> MijiResult<AccountModel> {
        self.inner.create(txn, data).await
    }

    async fn update_in_txn(
        &self,
        txn: &DbConn,
        id: String,
        data: AccountUpdate,
    ) -> MijiResult<AccountModel> {
        self.inner.update(txn, id, data).await
    }

    async fn delete_in_txn(&self, txn: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(txn, id).await
    }
}

impl AccountService {
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

        let owner_ids: Vec<String> = rows_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.clone())
            .map(|id| sanitize_input(&id))
            .collect();
        let family_member_service = get_family_member_service();
        let owners_map = family_member_service
            .family_member_batch_get(db, &owner_ids)
            .await?;

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
        let model = self.update(db, serial_num, data).await?;
        self.get_account_with_relations(db, model.serial_num).await
    }

    pub async fn update_account_active(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        is_active: bool,
    ) -> MijiResult<AccountWithRelations> {
        update_account_columns(
            db,
            std::iter::once(serial_num.clone()),
            [
                (
                    entity::account::Column::IsActive,
                    Expr::value(is_active as i32),
                ),
                (
                    entity::account::Column::UpdatedAt,
                    Expr::value(Some(DateUtils::local_rfc3339())),
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

        let owner_ids: Vec<String> = rows_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.clone())
            .map(|id| sanitize_input(&id))
            .collect();
        let family_member_service = get_family_member_service();
        let owners_map = family_member_service
            .family_member_batch_get(db, &owner_ids)
            .await?;

        let rows_converted: Vec<AccountWithRelations> = rows_with_currency
            .into_iter()
            .filter_map(|(account, currency_opt)| {
                let currency = currency_opt?;
                Some(AccountWithRelations {
                    account: account.clone().to_local(),
                    currency: currency.to_local(),
                    owner: account
                        .owner_id
                        .as_ref()
                        .and_then(|id| owners_map.get(id))
                        .cloned(),
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
            .filter(AccountColumn::IsActive.eq(1));

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

        // 计算 total_balance, adjusted_net_worth, total_assets
        let total_balance_expr = Expr::val(0.0)
            .add(create_sum_expr(AccountType::Savings, false))
            .add(create_sum_expr(AccountType::Bank, false))
            .add(create_sum_expr(AccountType::Cash, false))
            .add(create_sum_expr(AccountType::CreditCard, true)) // 信用卡取绝对值
            .add(create_sum_expr(AccountType::Investment, false))
            .add(create_sum_expr(AccountType::Alipay, false))
            .add(create_sum_expr(AccountType::WeChat, false))
            .add(create_sum_expr(AccountType::CloudQuickPass, false))
            .add(create_sum_expr(AccountType::Other, false))
            .cast_as(Alias::new("DECIMAL(16, 4)"));

        let adjusted_net_worth_expr = Expr::val(0.0)
            .add(create_sum_expr(AccountType::Savings, false))
            .add(create_sum_expr(AccountType::Bank, false))
            .add(create_sum_expr(AccountType::Cash, false))
            .sub(create_sum_expr(AccountType::CreditCard, true)) // 信用卡负向计算
            .add(create_sum_expr(AccountType::Investment, false))
            .add(create_sum_expr(AccountType::Alipay, false))
            .add(create_sum_expr(AccountType::WeChat, false))
            .add(create_sum_expr(AccountType::CloudQuickPass, false))
            .add(create_sum_expr(AccountType::Other, false))
            .cast_as(Alias::new("DECIMAL(16, 4)"));

        let total_assets_expr = Expr::val(0.0)
            .add(create_sum_expr(AccountType::Savings, false))
            .add(create_sum_expr(AccountType::Bank, false))
            .add(create_sum_expr(AccountType::Cash, false))
            .add(create_sum_expr(AccountType::Investment, false))
            .add(create_sum_expr(AccountType::Alipay, false))
            .add(create_sum_expr(AccountType::WeChat, false))
            .add(create_sum_expr(AccountType::CloudQuickPass, false))
            .add(create_sum_expr(AccountType::Other, false))
            .cast_as(Alias::new("DECIMAL(16, 4)"));

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
}

/// ---------------------------------------------
/// 辅助函数
/// ---------------------------------------------
fn cast_decimal<T: Into<SimpleExpr>>(expr: T) -> SimpleExpr {
    expr.into().cast_as(Alias::new("DECIMAL(16,4)"))
}

// 辅助函数：创建 SUM 表达式
fn create_sum_expr(account_type: AccountType, use_abs: bool) -> SimpleExpr {
    let condition = Condition::all().add(AccountColumn::Type.eq(account_type.as_ref()));
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

/// ---------------------------------------------
/// 获取服务实例
/// ---------------------------------------------
pub fn get_account_service() -> AccountService {
    AccountService::get_service()
}
