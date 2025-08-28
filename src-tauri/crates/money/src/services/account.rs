use common::{
    BusinessCode,
    crud::service::{CrudConverter, CrudService, GenericCrudService, TransactionalCrudService},
    error::{AppError, MijiResult},
    log::logger::{NoopLogger, OperationLogger},
    paginations::{DateRange, Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use sea_orm::{
    prelude::{async_trait::async_trait},
    sea_query::{Alias, Expr, ExprTrait, Func, SimpleExpr},
    ActiveModelTrait, ActiveValue::Set, ColumnTrait,
    Condition, DatabaseConnection, DbConn,
    EntityTrait, IntoActiveModel, PaginatorTrait, QueryFilter, QueryOrder, QuerySelect, SelectTwo
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::{collections::HashMap, str::FromStr};
use tracing::info;
use validator::Validate;

use crate::{
    dto::account::{AccountBalanceSummary, CreateAccountRequest, UpdateAccountRequest},
    services::account_hooks::AccountHooks,
};
use entity::{
    account::{Column as AccountColumn, Entity as AccountEntity, Model as AccountModel},
    currency::{Column as CurrencyColumn, Entity as CurrencyEntity, Model as CurrencyModel},
    family_member::{
        Column as FamilyMemberColumn, Entity as FamilyMemberEntity, Model as FamilyMemberModel,
    },
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

impl Filter<entity::account::Entity> for AccountFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();
        if let Some(name) = &self.name {
            condition = condition.add(AccountColumn::Name.eq(Self::sanitize_input(name)));
        }
        if let Some(r#type) = &self.r#type {
            condition = condition.add(AccountColumn::Type.eq(Self::sanitize_input(r#type)));
        }
        if let Some(currency) = &self.currency {
            condition = condition.add(AccountColumn::Currency.eq(Self::sanitize_input(currency)));
        }
        if let Some(is_shared) = self.is_shared {
            condition = condition.add(AccountColumn::IsShared.eq(is_shared as i32));
        }
        if let Some(owner_id) = &self.owner_id {
            condition = condition.add(AccountColumn::OwnerId.eq(Self::sanitize_input(owner_id)));
        }
        if let Some(is_active) = self.is_active {
            condition = condition.add(AccountColumn::IsActive.eq(is_active as i32));
        }
        if let Some(created_range) = &self.created_at_range {
            if let Some(start) = &created_range.start {
                condition = condition.add(AccountColumn::CreatedAt.gte(start.clone()));
            }
            if let Some(end) = &created_range.end {
                condition = condition.add(AccountColumn::CreatedAt.lte(end.clone()));
            }
        }
        if let Some(updated_range) = &self.updated_at_range {
            if let Some(start) = &updated_range.start {
                condition = condition.add(AccountColumn::UpdatedAt.gte(start.clone()));
            }
            if let Some(end) = &updated_range.end {
                condition = condition.add(AccountColumn::UpdatedAt.lte(end.clone()));
            }
        }
        condition
    }
}

impl AccountFilter {
    /// 输入清理，防止 SQL 注入
    fn sanitize_input(input: &str) -> String {
        input
            .trim()
            .replace(';', "")
            .replace("--", "")
            .replace("/*", "")
            .replace("*/", "")
    }
}

/// 包含完整关联信息的账户数据结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountWithRelations {
    pub account: AccountModel,
    pub currency: CurrencyModel,
    pub owner: Option<FamilyMemberModel>,
}

/// 账户转换器
#[derive(Debug)]
pub struct AccountConverter;

impl CrudConverter<AccountEntity, CreateAccountRequest, UpdateAccountRequest> for AccountConverter {
    fn create_to_active_model(
        &self,
        data: CreateAccountRequest,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: AccountModel,
        data: UpdateAccountRequest,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data)
            .map(|mut active_model| {
                active_model.serial_num = Set(model.serial_num.clone());
                active_model.created_at = Set(model.created_at.clone());
                active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));
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

/// 关联加载器 trait
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

/// 默认账户加载器
pub struct CurrencyLoader;

#[async_trait]
impl RelationLoader<AccountEntity> for CurrencyLoader {
    type Model = CurrencyModel;
    async fn load(&self, db: &DbConn, account: &AccountModel) -> MijiResult<Option<CurrencyModel>> {
        CurrencyEntity::find_by_id(account.currency.clone())
            .one(db)
            .await
            .map_err(AppError::from)
    }

    async fn batch_load(
        &self,
        db: &DbConn,
        ids: &[String],
    ) -> MijiResult<HashMap<String, CurrencyModel>> {
        if ids.is_empty() {
            return Ok(HashMap::new());
        }
        const CHUNK_SIZE: usize = 1000;
        let mut result = HashMap::new();
        for chunk in ids.chunks(CHUNK_SIZE) {
            let models = CurrencyEntity::find()
                .filter(CurrencyColumn::Code.is_in(chunk))
                .all(db)
                .await
                .map_err(AppError::from)?;
            result.extend(models.into_iter().map(|m| (m.code.clone(), m)));
        }
        Ok(result)
    }
}

pub struct FamilyMemberLoader;
#[async_trait]
impl RelationLoader<FamilyMemberEntity> for FamilyMemberLoader {
    type Model = FamilyMemberModel;
    async fn load(
        &self,
        db: &DbConn,
        family_member: &FamilyMemberModel,
    ) -> MijiResult<Option<FamilyMemberModel>> {
        FamilyMemberEntity::find_by_id(family_member.serial_num.clone())
            .one(db)
            .await
            .map_err(AppError::from)
    }

    async fn batch_load(
        &self,
        db: &DbConn,
        ids: &[String],
    ) -> MijiResult<HashMap<String, FamilyMemberModel>> {
        if ids.is_empty() {
            return Ok(HashMap::new());
        }
        const CHUNK_SIZE: usize = 1000;
        let mut result = HashMap::new();
        for chunk in ids.chunks(CHUNK_SIZE) {
            let owners = FamilyMemberEntity::find()
                .filter(FamilyMemberColumn::SerialNum.is_in(chunk))
                .all(db)
                .await
                .map_err(AppError::from)?;
            result.extend(
                owners
                    .into_iter()
                    .map(|owner| (owner.serial_num.clone(), owner)),
            );
        }
        Ok(result)
    }
}

impl FamilyMemberLoader {
    async fn load_by_id(
        &self,
        db: &DbConn,
        serial_num: &str,
    ) -> MijiResult<Option<FamilyMemberModel>> {
        FamilyMemberEntity::find_by_id(AccountFilter::sanitize_input(serial_num))
            .one(db)
            .await
            .map_err(AppError::from)
    }
}

/// 账户服务类型别名
pub type BaseAccountService = GenericCrudService<
    AccountEntity,
    AccountFilter,
    CreateAccountRequest,
    UpdateAccountRequest,
    AccountConverter,
    AccountHooks,
>;

pub struct AccountService {
    inner: BaseAccountService,
}

/// 账户类型配置，用于动态处理 total_assets
#[derive(Debug, Clone)]
struct AccountTypeConfig {
    struct_field: &'static str,
    condition: Condition,
    balance_expr: SimpleExpr,
    include_in_total_assets: bool,
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
    fn account_type_configs() -> Vec<AccountTypeConfig> {
        vec![
            AccountTypeConfig {
                struct_field: "bank_savings_balance",
                condition: Condition::all().add(AccountColumn::Type.eq("Savings")),
                balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
                include_in_total_assets: true,
            },
            AccountTypeConfig {
                struct_field: "cash_balance",
                condition: Condition::all().add(AccountColumn::Type.eq("Cash")),
                balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
                include_in_total_assets: true,
            },
            AccountTypeConfig {
                struct_field: "credit_card_balance",
                condition: Condition::all().add(AccountColumn::Type.eq("CreditCard")),
                balance_expr: cast_decimal(SimpleExpr::FunctionCall(Func::abs(Expr::col(
                    AccountColumn::Balance,
                )))),
                include_in_total_assets: true,
            },
            AccountTypeConfig {
                struct_field: "investment_balance",
                condition: Condition::all().add(AccountColumn::Type.eq("Investment")),
                balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
                include_in_total_assets: true,
            },
            AccountTypeConfig {
                struct_field: "alipay_balance",
                condition: Condition::all().add(AccountColumn::Type.eq("Alipay")),
                balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
                include_in_total_assets: true,
            },
            AccountTypeConfig {
                struct_field: "wechat_balance",
                condition: Condition::all().add(AccountColumn::Type.eq("WeChat")),
                balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
                include_in_total_assets: true,
            },
            AccountTypeConfig {
                struct_field: "cloud_quick_pass_balance",
                condition: Condition::all().add(AccountColumn::Type.eq("CloudQuickPass")),
                balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
                include_in_total_assets: true,
            },
            AccountTypeConfig {
                struct_field: "other_balance",
                condition: Condition::all().add(AccountColumn::Type.eq("Other")),
                balance_expr: cast_decimal(Expr::col(AccountColumn::Balance)),
                include_in_total_assets: true,
            },
        ]
    }
}

#[async_trait]
impl CrudService<AccountEntity, AccountFilter, CreateAccountRequest, UpdateAccountRequest>
    for AccountService
{
    async fn create(&self, db: &DbConn, data: CreateAccountRequest) -> MijiResult<AccountModel> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(&self, db: &DbConn, id: String) -> MijiResult<AccountModel> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DbConn,
        serial_num: String,
        data: UpdateAccountRequest,
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
        data: Vec<CreateAccountRequest>,
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
impl
    TransactionalCrudService<
        AccountEntity,
        AccountFilter,
        CreateAccountRequest,
        UpdateAccountRequest,
    > for AccountService
{
    async fn create_in_txn(
        &self,
        txn: &DbConn,
        data: CreateAccountRequest,
    ) -> MijiResult<AccountModel> {
        self.inner.create(txn, data).await
    }

    async fn update_in_txn(
        &self,
        txn: &DbConn,
        id: String,
        data: UpdateAccountRequest,
    ) -> MijiResult<AccountModel> {
        self.inner.update(txn, id, data).await
    }

    async fn delete_in_txn(&self, txn: &DbConn, id: String) -> MijiResult<()> {
        self.inner.delete(txn, id).await
    }
}

impl AccountService {
    pub async fn create_account(
        &self,
        db: &DatabaseConnection,
        data: CreateAccountRequest,
    ) -> MijiResult<AccountWithRelations> {
        let account = self.inner.create(db, data).await?;
        let account_with_relations = self
            .get_account_with_relations(db, account.serial_num.clone())
            .await?;
        Ok(account_with_relations)
    }

    pub async fn get_account_with_currency(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<(AccountModel, CurrencyModel)> {
        info!("[AccountService get_account_with_currency] start...");
        AccountEntity::find_by_id(AccountFilter::sanitize_input(&id))
            .find_also_related(CurrencyEntity)
            .one(db)
            .await
            .map_err(AppError::from)?
            .and_then(|(account, currency)| currency.map(|c| (account, c)))
            .ok_or_else(|| {
                AppError::simple(BusinessCode::NotFound, "Account or currency not found")
            })
    }

    pub async fn get_account_with_relations(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<AccountWithRelations> {
        info!("AccountService start....");
        let (account, currency) = self
            .get_account_with_currency(db, serial_num.clone())
            .await?;
        let owner = if let Some(owner_id) = &account.owner_id {
            FamilyMemberLoader.load_by_id(db, owner_id).await?
        } else {
            None
        };
        Ok(AccountWithRelations {
            account,
            currency,
            owner,
        })
    }

    pub async fn get_account_with_relations_optimized(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<AccountWithRelations> {
        let result = AccountEntity::find_by_id(AccountFilter::sanitize_input(&serial_num))
            .select_only()
            .columns([
                AccountColumn::SerialNum,
                AccountColumn::Name,
                AccountColumn::Currency,
            ])
            .find_also_related(CurrencyEntity)
            .select_only()
            .columns([CurrencyColumn::Code, CurrencyColumn::Symbol])
            .find_also_related(FamilyMemberEntity)
            .select_only()
            .columns([FamilyMemberColumn::SerialNum, FamilyMemberColumn::Name])
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Account not found"))?;
        let (account, currency, owner) = result;
        let currency = currency.ok_or_else(|| {
            AppError::simple(BusinessCode::NotFound, "Currency information missing")
        })?;
        Ok(AccountWithRelations {
            account,
            currency,
            owner,
        })
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
                account,
                currency,
                owner,
            },
        )
        .await
    }

    pub async fn list_accounts_paged_with_currency(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<PagedResult<(AccountModel, CurrencyModel)>> {
        Self::paginate_with_relations_base(
            db,
            AccountEntity::find().find_also_related(CurrencyEntity),
            query,
            |(account, currency, _)| (account, currency),
        )
        .await
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
            .map(|id| AccountFilter::sanitize_input(&id))
            .collect();
        let owners_map = FamilyMemberLoader.batch_load(db, &owner_ids).await?;

        let rows = rows_with_currency
            .into_iter()
            .filter_map(|(account, currency)| {
                currency.map(|c| {
                    let owner = account
                        .owner_id
                        .as_ref()
                        .and_then(|id| owners_map.get(id))
                        .cloned();
                    transform((account, c, owner))
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

    pub async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        query: AccountFilter,
    ) -> MijiResult<PagedResult<(AccountModel, CurrencyModel, Option<FamilyMemberModel>)>> {
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
            .map(|id| AccountFilter::sanitize_input(&id))
            .collect();
        let owners_map = FamilyMemberLoader.batch_load(db, &owner_ids).await?;

        let rows: Vec<(AccountModel, CurrencyModel, Option<FamilyMemberModel>)> =
            rows_with_currency
                .into_iter()
                .filter_map(|(account, currency)| {
                    currency.map(|c| {
                        (
                            account.clone(),
                            c,
                            account
                                .owner_id
                                .as_ref()
                                .and_then(|id| owners_map.get(id))
                                .cloned(),
                        )
                    })
                })
                .collect();

        let total_count = rows.len();
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
    ) -> MijiResult<AccountWithRelations> {
        let account = AccountEntity::find_by_id(AccountFilter::sanitize_input(&serial_num))
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    format!("Account with serial_num: {serial_num}"),
                )
            })?;

        let mut active_model = account.into_active_model();
        active_model.is_active = Set(is_active as i32);
        active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));
        active_model.update(db).await.map_err(AppError::from)?;

        self.get_account_with_relations(db, serial_num).await
    }

    pub async fn total_assets(&self, db: &DatabaseConnection) -> MijiResult<AccountBalanceSummary> {
        let mut query = AccountEntity::find()
            .select_only()
            .filter(AccountColumn::IsActive.eq(1));

        for config in Self::account_type_configs() {
            let expr = Expr::val(0.0).add(
                SimpleExpr::FunctionCall(Func::coalesce(vec![
                    SimpleExpr::FunctionCall(Func::sum(
                        Expr::case(config.condition, config.balance_expr)
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
        .add(create_sum_expr("Savings", false))
        .add(create_sum_expr("Cash", false))
        .add(create_sum_expr("CreditCard", true)) // 对信用卡使用 ABS
        .add(create_sum_expr("Investment", false))
        .add(create_sum_expr("Alipay", false))
        .add(create_sum_expr("WeChat", false))
        .add(create_sum_expr("CloudQuickPass", false))
        .add(create_sum_expr("Other", false))
        .cast_as(Alias::new("DECIMAL(16, 4)"));

    let adjusted_net_worth_expr = Expr::val(0.0)
        .add(create_sum_expr("Savings", false))
        .add(create_sum_expr("Cash", false))
        .sub(create_sum_expr("CreditCard", true)) // 信用卡负向计算
        .add(create_sum_expr("Investment", false))
        .add(create_sum_expr("Alipay", false))
        .add(create_sum_expr("WeChat", false))
        .add(create_sum_expr("CloudQuickPass", false))
        .add(create_sum_expr("Other", false))
        .cast_as(Alias::new("DECIMAL(16, 4)"));

    let total_assets_expr = Expr::val(0.0)
        .add(create_sum_expr("Savings", false))
        .add(create_sum_expr("Cash", false))
        .add(create_sum_expr("Investment", false))
        .add(create_sum_expr("Alipay", false))
        .add(create_sum_expr("WeChat", false))
        .add(create_sum_expr("CloudQuickPass", false))
        .add(create_sum_expr("Other", false))
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

    fn apply_sort_to_select_two(
        query_builder: SelectTwo<AccountEntity, CurrencyEntity>,
        sort_by: &Option<String>,
        desc: bool,
    ) -> SelectTwo<AccountEntity, CurrencyEntity> {
        let Some(sort_by) = sort_by else {
            return query_builder;
        };

        let sort_by = AccountFilter::sanitize_input(sort_by);

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

fn cast_decimal<T: Into<SimpleExpr>>(expr: T) -> SimpleExpr {
    expr.into().cast_as(Alias::new("DECIMAL(16,4)"))
}

// 辅助函数：创建 SUM 表达式
fn create_sum_expr(account_type: &str, use_abs: bool) -> SimpleExpr {
    let condition = Condition::all().add(AccountColumn::Type.eq(account_type));
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

pub fn get_account_service() -> AccountService {
    AccountService::get_service()
}
