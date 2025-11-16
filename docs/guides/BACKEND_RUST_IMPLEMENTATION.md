# Rust/Tauri 后端实现指南

**版本**: 1.0  
**日期**: 2025-11-16  
**技术栈**: Rust + Tauri + SeaORM

---

## 📋 API 实现清单

### 1. 分摊模板 API (4个)

#### 1.1 创建分摊模板
```rust
// src-tauri/src/commands/split_template.rs

#[tauri::command]
pub async fn split_template_create(
    state: State<'_, AppState>,
    data: SplitTemplateCreateRequest,
) -> Result<SplitTemplateResponse, String> {
    let db = &state.db;
    
    // 1. 验证数据
    validate_split_template(&data)?;
    
    // 2. 如果设为默认，取消其他默认模板
    if data.is_default {
        SplitRule::update_many()
            .col_expr(split_rule::Column::IsDefault, Expr::value(false))
            .filter(split_rule::Column::FamilyLedgerSerialNum.eq(&data.family_ledger_serial_num))
            .exec(db)
            .await?;
    }
    
    // 3. 创建模板
    let template = split_rule::ActiveModel {
        serial_num: Set(generate_serial_num()),
        name: Set(data.name),
        description: Set(data.description),
        rule_type: Set(data.rule_type),
        is_default: Set(data.is_default.unwrap_or(false)),
        is_template: Set(true),
        ..Default::default()
    };
    
    let result = template.insert(db).await?;
    
    // 4. 创建参与成员配置
    if let Some(participants) = data.participants {
        for p in participants {
            let member = split_member::ActiveModel {
                split_rule_serial_num: Set(result.serial_num.clone()),
                member_serial_num: Set(p.member_serial_num),
                percentage: Set(p.percentage),
                amount: Set(p.amount),
                weight: Set(p.weight),
                ..Default::default()
            };
            member.insert(db).await?;
        }
    }
    
    Ok(to_response(result))
}

// 验证函数
fn validate_split_template(data: &SplitTemplateCreateRequest) -> Result<(), String> {
    match data.rule_type.as_str() {
        "PERCENTAGE" => {
            if let Some(participants) = &data.participants {
                let total: f64 = participants.iter()
                    .filter_map(|p| p.percentage)
                    .sum();
                if (total - 100.0).abs() > 0.01 {
                    return Err("比例总和必须为100%".to_string());
                }
            }
        },
        "WEIGHTED" => {
            if let Some(participants) = &data.participants {
                let total: i32 = participants.iter()
                    .filter_map(|p| p.weight)
                    .sum();
                if total <= 0 {
                    return Err("权重总和必须大于0".to_string());
                }
            }
        },
        _ => {}
    }
    Ok(())
}
```

#### 1.2 获取模板列表
```rust
#[tauri::command]
pub async fn split_template_list(
    state: State<'_, AppState>,
    params: SplitTemplateListRequest,
) -> Result<SplitTemplateListResponse, String> {
    let db = &state.db;
    
    let mut query = SplitRule::find()
        .filter(split_rule::Column::IsTemplate.eq(true));
    
    // 添加筛选条件
    if let Some(ledger) = params.family_ledger_serial_num {
        query = query.filter(split_rule::Column::FamilyLedgerSerialNum.eq(ledger));
    }
    
    if let Some(rule_type) = params.rule_type {
        query = query.filter(split_rule::Column::RuleType.eq(rule_type));
    }
    
    // 分页
    let page = params.page.unwrap_or(1);
    let page_size = params.page_size.unwrap_or(20);
    
    let paginator = query.paginate(db, page_size);
    let total = paginator.num_items().await?;
    let templates = paginator.fetch_page(page - 1).await?;
    
    Ok(SplitTemplateListResponse {
        templates: templates.into_iter().map(to_response).collect(),
        total,
        page,
        page_size,
    })
}
```

---

### 2. 分摊记录 API (4个)

#### 2.1 创建分摊记录
```rust
#[tauri::command]
pub async fn split_record_create(
    state: State<'_, AppState>,
    data: SplitRecordCreateRequest,
) -> Result<SplitRecordResponse, String> {
    let db = &state.db;
    
    // 开启事务
    let txn = db.begin().await?;
    
    // 1. 验证总金额
    let calculated_total: f64 = data.split_details.iter()
        .map(|d| d.amount)
        .sum();
    
    if (calculated_total - data.total_amount).abs() > 0.01 {
        return Err("分摊金额总和不等于总金额".to_string());
    }
    
    // 2. 创建分摊记录
    let record = split_record::ActiveModel {
        serial_num: Set(generate_serial_num()),
        transaction_serial_num: Set(data.transaction_serial_num),
        family_ledger_serial_num: Set(data.family_ledger_serial_num),
        rule_type: Set(data.rule_type),
        total_amount: Set(data.total_amount),
        ..Default::default()
    };
    
    let result = record.insert(&txn).await?;
    
    // 3. 创建分摊明细
    for detail in data.split_details {
        let detail_model = split_record_detail::ActiveModel {
            split_record_serial_num: Set(result.serial_num.clone()),
            member_serial_num: Set(detail.member_serial_num),
            amount: Set(detail.amount),
            percentage: Set(detail.percentage),
            weight: Set(detail.weight),
            is_paid: Set(detail.is_paid),
            ..Default::default()
        };
        detail_model.insert(&txn).await?;
    }
    
    txn.commit().await?;
    
    Ok(to_response(result))
}
```

#### 2.2 查询分摊记录列表
```rust
#[tauri::command]
pub async fn split_record_list(
    state: State<'_, AppState>,
    params: SplitRecordListRequest,
) -> Result<SplitRecordListResponse, String> {
    let db = &state.db;
    
    let mut query = SplitRecord::find();
    
    // 筛选条件
    if let Some(ledger) = params.family_ledger_serial_num {
        query = query.filter(split_record::Column::FamilyLedgerSerialNum.eq(ledger));
    }
    
    if let Some(rule_type) = params.rule_type {
        query = query.filter(split_record::Column::RuleType.eq(rule_type));
    }
    
    // 日期范围
    if let Some(start_date) = params.start_date {
        query = query.filter(split_record::Column::CreatedAt.gte(start_date));
    }
    
    if let Some(end_date) = params.end_date {
        query = query.filter(split_record::Column::CreatedAt.lte(end_date));
    }
    
    // 金额范围
    if let Some(min_amount) = params.min_amount {
        query = query.filter(split_record::Column::TotalAmount.gte(min_amount));
    }
    
    if let Some(max_amount) = params.max_amount {
        query = query.filter(split_record::Column::TotalAmount.lte(max_amount));
    }
    
    // 分页
    let page = params.page.unwrap_or(1);
    let page_size = params.page_size.unwrap_or(20);
    
    let paginator = query.paginate(db, page_size);
    let total = paginator.num_items().await?;
    let records = paginator.fetch_page(page - 1).await?;
    
    // 计算统计信息
    let statistics = calculate_statistics(&records, db).await?;
    
    Ok(SplitRecordListResponse {
        records: records.into_iter().map(to_response).collect(),
        total,
        page,
        page_size,
        statistics,
    })
}
```

#### 2.3 更新支付状态
```rust
#[tauri::command]
pub async fn split_record_update_status(
    state: State<'_, AppState>,
    data: SplitRecordUpdateStatusRequest,
) -> Result<SplitRecordUpdateStatusResponse, String> {
    let db = &state.db;
    
    // 查找明细记录
    let detail = SplitRecordDetail::find()
        .filter(split_record_detail::Column::SplitRecordSerialNum.eq(&data.serial_num))
        .filter(split_record_detail::Column::MemberSerialNum.eq(&data.member_serial_num))
        .one(db)
        .await?
        .ok_or("分摊明细不存在")?;
    
    // 更新状态
    let mut detail: split_record_detail::ActiveModel = detail.into();
    detail.is_paid = Set(data.is_paid);
    detail.paid_at = Set(data.paid_at);
    detail.updated_at = Set(Some(chrono::Utc::now().naive_utc()));
    
    let updated = detail.update(db).await?;
    
    Ok(SplitRecordUpdateStatusResponse {
        success: true,
        message: "更新成功".to_string(),
        updated_detail: to_detail_response(updated),
    })
}
```

---

### 3. 交易集成 API (扩展现有接口)

#### 3.1 扩展交易创建
```rust
// src-tauri/src/commands/transaction.rs

#[tauri::command]
pub async fn transaction_create(
    state: State<'_, AppState>,
    data: TransactionCreateRequest,
) -> Result<TransactionResponse, String> {
    let db = &state.db;
    
    // 开启事务
    let txn = db.begin().await?;
    
    // 1. 创建交易（现有逻辑）
    let transaction = create_transaction_internal(&txn, &data).await?;
    
    // 2. 如果有分摊配置，创建分摊记录
    if let Some(split_config) = data.split_config {
        if split_config.enabled {
            create_split_record(&txn, &transaction, split_config).await?;
        }
    }
    
    txn.commit().await?;
    
    Ok(to_response(transaction))
}

// 创建分摊记录的内部函数
async fn create_split_record(
    txn: &DatabaseTransaction,
    transaction: &transaction::Model,
    config: SplitConfig,
) -> Result<(), String> {
    // 创建分摊记录
    let split_record = split_record::ActiveModel {
        serial_num: Set(generate_serial_num()),
        transaction_serial_num: Set(transaction.serial_num.clone()),
        family_ledger_serial_num: Set(transaction.family_ledger_serial_num.clone().unwrap()),
        rule_type: Set(config.rule_type),
        total_amount: Set(transaction.amount),
        ..Default::default()
    };
    
    let record = split_record.insert(txn).await?;
    
    // 创建分摊明细
    for member in config.members {
        let detail = split_record_detail::ActiveModel {
            split_record_serial_num: Set(record.serial_num.clone()),
            member_serial_num: Set(member.member_serial_num),
            amount: Set(member.amount),
            percentage: Set(member.percentage),
            weight: Set(member.weight),
            is_paid: Set(false),
            ..Default::default()
        };
        detail.insert(txn).await?;
    }
    
    Ok(())
}
```

#### 3.2 扩展交易查询
```rust
#[tauri::command]
pub async fn transaction_detail(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<TransactionDetailResponse, String> {
    let db = &state.db;
    
    // 1. 查询交易
    let transaction = Transaction::find_by_id(serial_num.clone())
        .one(db)
        .await?
        .ok_or("交易不存在")?;
    
    // 2. 查询分摊记录
    let split_record = SplitRecord::find()
        .filter(split_record::Column::TransactionSerialNum.eq(&serial_num))
        .find_with_related(SplitRecordDetail)
        .one(db)
        .await?;
    
    Ok(TransactionDetailResponse {
        ..to_response(transaction),
        split_record: split_record.map(to_split_response),
    })
}

#[tauri::command]
pub async fn transaction_list(
    state: State<'_, AppState>,
    params: TransactionListRequest,
) -> Result<TransactionListResponse, String> {
    let db = &state.db;
    
    // 查询交易列表
    let transactions = query_transactions(db, &params).await?;
    
    // 批量查询分摊标识
    let transaction_ids: Vec<String> = transactions.iter()
        .map(|t| t.serial_num.clone())
        .collect();
    
    let split_records = SplitRecord::find()
        .filter(split_record::Column::TransactionSerialNum.is_in(transaction_ids))
        .all(db)
        .await?;
    
    // 构建分摊标识映射
    let split_map: HashMap<String, (bool, String, usize)> = split_records.into_iter()
        .map(|r| (
            r.transaction_serial_num.clone(),
            (true, r.rule_type.clone(), r.member_count())
        ))
        .collect();
    
    // 添加分摊标识
    let items: Vec<TransactionListItem> = transactions.into_iter()
        .map(|t| {
            let (has_split, rule_type, member_count) = split_map
                .get(&t.serial_num)
                .cloned()
                .unwrap_or((false, String::new(), 0));
            
            TransactionListItem {
                ..to_list_item(t),
                has_split,
                split_rule_type: if has_split { Some(rule_type) } else { None },
                split_member_count: if has_split { Some(member_count) } else { None },
            }
        })
        .collect();
    
    Ok(TransactionListResponse {
        items,
        ..Default::default()
    })
}
```

---

## 📦 数据模型定义

### Rust Entity Models
```rust
// src-tauri/src/entities/split_rule.rs

use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "split_rules")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub serial_num: String,
    pub family_ledger_serial_num: Option<String>,
    pub name: String,
    pub description: Option<String>,
    pub rule_type: String,
    pub is_template: bool,
    pub is_default: bool,
    pub is_active: bool,
    pub created_at: DateTime,
    pub updated_at: Option<DateTime>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::split_member::Entity")]
    SplitMembers,
}
```

### Request/Response DTOs
```rust
// src-tauri/src/dto/split.rs

use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct SplitTemplateCreateRequest {
    pub name: String,
    pub description: Option<String>,
    pub rule_type: String,
    pub is_default: Option<bool>,
    pub family_ledger_serial_num: Option<String>,
    pub participants: Option<Vec<ParticipantConfig>>,
}

#[derive(Debug, Deserialize)]
pub struct ParticipantConfig {
    pub member_serial_num: String,
    pub percentage: Option<f64>,
    pub amount: Option<f64>,
    pub weight: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct SplitTemplateResponse {
    pub serial_num: String,
    pub name: String,
    pub description: Option<String>,
    pub rule_type: String,
    pub is_default: bool,
    pub participants: Vec<ParticipantResponse>,
    pub created_at: String,
    pub updated_at: Option<String>,
}
```

---

## 🔧 工具函数

### 序列号生成
```rust
pub fn generate_serial_num() -> String {
    use uuid::Uuid;
    format!("SR{}", Uuid::new_v4().to_string().replace("-", "")[..12].to_uppercase())
}
```

### 尾数处理
```rust
pub fn handle_remainder(members: &mut Vec<SplitMember>, total_amount: f64) {
    let calculated_total: f64 = members.iter().map(|m| m.amount).sum();
    let remainder = total_amount - calculated_total;
    
    if remainder.abs() > 0.01 && !members.is_empty() {
        members[0].amount += remainder;
    }
}
```

---

## 📋 注册 Tauri Commands

```rust
// src-tauri/src/main.rs

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            // 分摊模板
            split_template_create,
            split_template_list,
            split_template_update,
            split_template_delete,
            
            // 分摊记录
            split_record_create,
            split_record_list,
            split_record_detail,
            split_record_update_status,
            
            // 交易集成（扩展）
            transaction_create,
            transaction_update,
            transaction_detail,
            transaction_list,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

---

## ✅ 实施检查清单

- [ ] 创建 Entity Models
- [ ] 创建 DTO 定义
- [ ] 实现分摊模板 CRUD
- [ ] 实现分摊记录 CRUD
- [ ] 扩展交易 API
- [ ] 注册 Tauri Commands
- [ ] 编写单元测试
- [ ] 编写集成测试
- [ ] 性能测试
- [ ] 文档更新

---

**文档版本**: 1.0  
**最后更新**: 2025-11-16 15:25  
**状态**: 实施指南
