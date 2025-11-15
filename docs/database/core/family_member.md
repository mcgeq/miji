# family_member - 家庭成员表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `family_member`
- **说明**: 家庭成员信息表，存储参与家庭账本的成员信息
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132220_create_family_member.rs`
- **扩展迁移**: `m20251112_000002_enhance_family_member_fields.rs`

## 📊 表结构

### 基础字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 成员唯一标识符（UUID格式） |
| `name` | VARCHAR | 100 | NOT NULL | - | 成员姓名 |
| `role` | VARCHAR | 20 | NOT NULL, CHECK | 'Member' | 成员角色 |
| `is_primary` | BOOLEAN | - | NOT NULL | false | 是否为主要成员 |
| `permissions` | TEXT | - | NOT NULL | '{}' | 权限配置（JSON格式） |
| `status` | VARCHAR | 20 | NOT NULL, CHECK | 'Active' | 成员状态 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**枚举值**:
- `role`: 'Owner', 'Admin', 'Member', 'Viewer'
- `status`: 'Active', 'Inactive', 'Suspended'

**用途说明**:
- `serial_num`: UUID 格式，确保全局唯一性
- `role`: 定义成员在账本中的权限级别
  - Owner: 账本所有者，拥有所有权限
  - Admin: 管理员，可管理成员和设置
  - Member: 普通成员，可记账和查看
  - Viewer: 观察者，只能查看
- `is_primary`: 标识主要负责人，用于默认选择
- `permissions`: JSON 格式存储细粒度权限配置

### 关联字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `user_id` | VARCHAR(38) | FK, NULLABLE | NULL | 关联的用户ID，外键到 `users.serial_num` |
| `avatar_url` | VARCHAR | NULLABLE | NULL | 头像URL |
| `color` | VARCHAR(7) | NULLABLE | NULL | 成员标识颜色（十六进制，如 #FF5733） |
| `email` | VARCHAR | NULLABLE | NULL | 电子邮箱 |
| `phone` | VARCHAR(20) | NULLABLE | NULL | 手机号码 |

**用途说明**:
- `user_id`: 可选关联到系统用户，未关联则为临时成员
- `avatar_url`: 存储头像图片的URL或路径
- `color`: 用于UI展示，区分不同成员
- `email` / `phone`: 联系方式，用于通知和结算

### 财务统计字段

| 字段名 | 类型 | 精度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `total_paid` | DECIMAL | (16, 4) | NOT NULL | 0.0000 | 累计支付金额 |
| `total_owed` | DECIMAL | (16, 4) | NOT NULL | 0.0000 | 累计欠款金额 |
| `balance` | DECIMAL | (16, 4) | NOT NULL | 0.0000 | 当前余额（total_paid - total_owed） |

**用途说明**:
- `total_paid`: 成员为账本支付的总金额
- `total_owed`: 成员应承担的总金额
- `balance`: 余额，正数表示多付（别人欠他），负数表示欠款（他欠别人）

**计算逻辑**:
```
balance = total_paid - total_owed

如果 balance > 0: 成员多付了，其他人欠他钱
如果 balance < 0: 成员欠款，需要还给其他人
如果 balance = 0: 收支平衡
```

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `users` | `user_id` → `serial_num` | ON DELETE: SET NULL<br>ON UPDATE: CASCADE | 关联系统用户 |

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `account` | 成员拥有的账户 |
| HAS_MANY | `family_ledger_member` | 成员参与的账本关联 |
| HAS_MANY | `split_records` (payer) | 作为支付方的分摊记录 |
| HAS_MANY | `split_records` (ower) | 作为欠款方的分摊记录 |
| HAS_MANY | `debt_relations` (creditor) | 作为债权人的债务关系 |
| HAS_MANY | `debt_relations` (debtor) | 作为债务人的债务关系 |
| HAS_MANY | `settlement_records` (initiator) | 发起的结算记录 |
| HAS_MANY | `settlement_records` (completer) | 完成的结算记录 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `family_ledger` | `family_ledger_member` | 成员可参与多个账本 |

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (serial_num)

-- 外键索引
CREATE INDEX idx_family_member_user_id ON family_member(user_id);

-- 状态查询索引
CREATE INDEX idx_family_member_status ON family_member(status);

-- 角色查询索引
CREATE INDEX idx_family_member_role ON family_member(role);

-- 复合索引（用于查询活跃的主要成员）
CREATE INDEX idx_family_member_status_primary 
ON family_member(status, is_primary) 
WHERE status = 'Active';
```

## 💡 使用示例

### 创建家庭成员

```rust
use entity::family_member;
use sea_orm::*;

let member = family_member::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("张三".to_string()),
    role: Set("Member".to_string()),
    is_primary: Set(false),
    permissions: Set("{}".to_string()),
    user_id: Set(Some("user_uuid_here".to_string())),
    avatar_url: Set(Some("/avatars/zhangsan.jpg".to_string())),
    color: Set(Some("#3B82F6".to_string())),
    email: Set(Some("zhangsan@example.com".to_string())),
    phone: Set(Some("13800138000".to_string())),
    total_paid: Set(Decimal::ZERO),
    total_owed: Set(Decimal::ZERO),
    balance: Set(Decimal::ZERO),
    status: Set("Active".to_string()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = member.insert(db).await?;
```

### 查询账本的所有成员

```rust
use entity::{family_member, family_ledger_member};

let members = FamilyMember::find()
    .inner_join(FamilyLedgerMember)
    .filter(family_ledger_member::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .filter(family_member::Column::Status.eq("Active"))
    .all(db)
    .await?;
```

### 更新成员余额

```rust
// 成员支付了 100 元
let member = family_member::Entity::find_by_id(member_id)
    .one(db)
    .await?
    .unwrap();

let mut active_member: family_member::ActiveModel = member.into();
active_member.total_paid = Set(active_member.total_paid.unwrap() + Decimal::from(100));
active_member.balance = Set(
    active_member.total_paid.unwrap() - active_member.total_owed.unwrap()
);
active_member.updated_at = Set(Some(Utc::now().into()));

active_member.update(db).await?;
```

### 查询欠款成员

```rust
// 查询所有欠款的成员（balance < 0）
let debtors = FamilyMember::find()
    .filter(family_member::Column::Balance.lt(Decimal::ZERO))
    .filter(family_member::Column::Status.eq("Active"))
    .all(db)
    .await?;
```

## ⚠️ 注意事项

1. **财务字段更新**: `total_paid`, `total_owed`, `balance` 应通过服务层统一更新，不要直接修改
2. **余额计算**: `balance` 应始终等于 `total_paid - total_owed`，更新时需保持一致性
3. **用户关联**: `user_id` 为 NULL 表示临时成员，删除用户时会自动设为 NULL
4. **权限验证**: 在执行操作前应检查成员的 `role` 和 `permissions`
5. **主要成员**: 每个账本建议只有一个 `is_primary = true` 的成员
6. **颜色格式**: `color` 字段应存储标准的十六进制颜色值（如 #FF5733）
7. **状态管理**: 只有 `Active` 状态的成员才能参与账本操作

## 🔄 状态转换

```
Active (活跃)
  ↓ 暂停使用
Inactive (非活跃)
  ↓ 违规或其他原因
Suspended (暂停)
  ↓ 重新激活
Active (活跃)
```

## 📝 权限配置示例

`permissions` 字段存储 JSON 格式的权限配置：

```json
{
  "canCreateTransaction": true,
  "canEditTransaction": true,
  "canDeleteTransaction": false,
  "canManageBudget": true,
  "canViewReports": true,
  "canManageMembers": false,
  "canExportData": true
}
```

## 🔗 相关表

- [family_ledger - 家庭账本表](./family_ledger.md)
- [family_ledger_member - 账本成员关联表](../association/family_ledger_member.md)
- [users - 用户表](./users.md)
- [account - 账户表](./account.md)
- [split_records - 分摊记录表](../financial/split_records.md)
- [debt_relations - 债务关系表](../financial/debt_relations.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
