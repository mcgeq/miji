# users - 用户表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `users`
- **说明**: 系统用户表，存储用户账号、认证和个人信息
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132225_create_users.rs`

## 📊 表结构

### 基础字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 用户唯一标识符（UUID格式） |
| `name` | VARCHAR | 50 | UNIQUE, NOT NULL | - | 用户名（全局唯一） |
| `email` | VARCHAR | 100 | UNIQUE, NOT NULL | - | 电子邮箱（全局唯一） |
| `phone` | VARCHAR | 20 | UNIQUE, NULLABLE | NULL | 手机号码（全局唯一） |
| `password` | VARCHAR | 255 | NOT NULL | - | 密码哈希值 |
| `avatar_url` | VARCHAR | 500 | NULLABLE | NULL | 头像URL |
| `bio` | TEXT | - | NULLABLE | NULL | 个人简介 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**:
- `serial_num`: UUID 格式，确保全局唯一性
- `name`: 用户名，用于登录和显示
- `email`: 邮箱地址，用于登录和通知
- `phone`: 手机号码，可选，用于登录和通知
- `password`: 存储加密后的密码哈希值，不存储明文
- `avatar_url`: 头像图片的URL或路径
- `bio`: 用户个人简介或签名

### 认证字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `is_verified` | BOOLEAN | NOT NULL | false | 是否已验证 |
| `email_verified_at` | TIMESTAMP WITH TIME ZONE | NULLABLE | NULL | 邮箱验证时间 |
| `phone_verified_at` | TIMESTAMP WITH TIME ZONE | NULLABLE | NULL | 手机验证时间 |
| `last_login_at` | TIMESTAMP WITH TIME ZONE | NULLABLE | NULL | 最后登录时间 |
| `last_active_at` | TIMESTAMP WITH TIME ZONE | NULLABLE | NULL | 最后活跃时间 |

**用途说明**:
- `is_verified`: 用户是否完成验证（邮箱或手机）
- `email_verified_at`: 邮箱验证的时间戳，NULL 表示未验证
- `phone_verified_at`: 手机验证的时间戳，NULL 表示未验证
- `last_login_at`: 记录用户最后一次登录时间
- `last_active_at`: 记录用户最后一次活动时间

### 权限字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `role` | VARCHAR | 20 | NOT NULL, CHECK | 'User' | 用户角色 |
| `status` | VARCHAR | 20 | NOT NULL, CHECK | 'Active' | 用户状态 |

**枚举值**:
- `role`: 'Admin', 'User', 'Guest'
- `status`: 'Active', 'Inactive', 'Suspended', 'Deleted'

**用途说明**:
- `role`: 
  - Admin: 管理员，拥有所有权限
  - User: 普通用户
  - Guest: 访客（受限权限）
- `status`:
  - Active: 活跃用户
  - Inactive: 非活跃用户（长时间未登录）
  - Suspended: 暂停使用（违规等）
  - Deleted: 已删除（软删除）

### 偏好设置字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `language` | VARCHAR | 10 | NULLABLE | NULL | 语言偏好（如 zh-CN, en-US） |
| `timezone` | VARCHAR | 50 | NULLABLE | NULL | 时区设置（如 Asia/Shanghai） |

**用途说明**:
- `language`: 用户界面语言偏好
- `timezone`: 用户所在时区，用于时间显示

### 软删除字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `deleted_at` | TIMESTAMP WITH TIME ZONE | NULLABLE | NULL | 删除时间（软删除标记） |

**用途说明**:
- `deleted_at`: NULL 表示未删除，有值表示已删除

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `family_member` | 用户可以是多个家庭成员 |
| HAS_MANY | `todo` | 用户的待办事项 |

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (serial_num)

-- 唯一索引（自动创建）
UNIQUE INDEX idx_users_name ON users(name);
UNIQUE INDEX idx_users_email ON users(email);
UNIQUE INDEX idx_users_phone ON users(phone) WHERE phone IS NOT NULL;

-- 状态查询索引
CREATE INDEX idx_users_status ON users(status);

-- 角色查询索引
CREATE INDEX idx_users_role ON users(role);

-- 软删除查询索引
CREATE INDEX idx_users_active 
ON users(status, deleted_at) 
WHERE deleted_at IS NULL;

-- 最后登录时间索引
CREATE INDEX idx_users_last_login ON users(last_login_at DESC);
```

## 💡 使用示例

### 创建用户

```rust
use entity::users;
use sea_orm::*;
use bcrypt::{hash, DEFAULT_COST};

// 密码加密
let password_hash = hash("user_password", DEFAULT_COST)?;

let user = users::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("zhangsan".to_string()),
    email: Set("zhangsan@example.com".to_string()),
    phone: Set(Some("13800138000".to_string())),
    password: Set(password_hash),
    avatar_url: Set(Some("/avatars/default.jpg".to_string())),
    bio: Set(Some("Hello, I'm Zhang San!".to_string())),
    is_verified: Set(false),
    role: Set("User".to_string()),
    status: Set("Active".to_string()),
    language: Set(Some("zh-CN".to_string())),
    timezone: Set(Some("Asia/Shanghai".to_string())),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = user.insert(db).await?;
```

### 用户登录验证

```rust
use bcrypt::verify;

// 通过邮箱查找用户
let user = Users::find()
    .filter(users::Column::Email.eq("zhangsan@example.com"))
    .filter(users::Column::Status.eq("Active"))
    .filter(users::Column::DeletedAt.is_null())
    .one(db)
    .await?
    .ok_or("User not found")?;

// 验证密码
let is_valid = verify("user_password", &user.password)?;

if is_valid {
    // 更新最后登录时间
    let mut active: users::ActiveModel = user.into();
    active.last_login_at = Set(Some(Utc::now().into()));
    active.last_active_at = Set(Some(Utc::now().into()));
    active.updated_at = Set(Some(Utc::now().into()));
    
    active.update(db).await?;
}
```

### 邮箱验证

```rust
let user = Users::find_by_id(user_id)
    .one(db)
    .await?
    .unwrap();

let mut active: users::ActiveModel = user.into();
active.is_verified = Set(true);
active.email_verified_at = Set(Some(Utc::now().into()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 更新用户信息

```rust
let user = Users::find_by_id(user_id)
    .one(db)
    .await?
    .unwrap();

let mut active: users::ActiveModel = user.into();
active.name = Set("newname".to_string());
active.bio = Set(Some("Updated bio".to_string()));
active.avatar_url = Set(Some("/avatars/new.jpg".to_string()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 修改密码

```rust
use bcrypt::hash;

let new_password_hash = hash("new_password", DEFAULT_COST)?;

let user = Users::find_by_id(user_id)
    .one(db)
    .await?
    .unwrap();

let mut active: users::ActiveModel = user.into();
active.password = Set(new_password_hash);
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 软删除用户

```rust
let user = Users::find_by_id(user_id)
    .one(db)
    .await?
    .unwrap();

let mut active: users::ActiveModel = user.into();
active.status = Set("Deleted".to_string());
active.deleted_at = Set(Some(Utc::now().into()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 查询活跃用户

```rust
let active_users = Users::find()
    .filter(users::Column::Status.eq("Active"))
    .filter(users::Column::DeletedAt.is_null())
    .all(db)
    .await?;
```

### 查询最近登录用户

```rust
let recent_users = Users::find()
    .filter(users::Column::Status.eq("Active"))
    .filter(users::Column::DeletedAt.is_null())
    .filter(users::Column::LastLoginAt.is_not_null())
    .order_by_desc(users::Column::LastLoginAt)
    .limit(10)
    .all(db)
    .await?;
```

## ⚠️ 注意事项

1. **密码安全**: 
   - 永远不要存储明文密码
   - 使用 bcrypt 或 argon2 等安全哈希算法
   - 密码哈希值长度至少 60 字符

2. **唯一性约束**: 
   - `name`, `email`, `phone` 必须全局唯一
   - 创建前需检查是否重复

3. **软删除**: 
   - 使用 `deleted_at` 标记删除，不要物理删除
   - 查询时需过滤 `deleted_at IS NULL`

4. **验证状态**: 
   - 未验证用户应限制某些功能
   - 定期清理长期未验证的用户

5. **会话管理**: 
   - 本表不存储会话信息
   - 会话应使用独立的 session 表或 Redis

6. **隐私保护**: 
   - 敏感信息（如邮箱、手机）应加密存储
   - API 返回时应脱敏处理

7. **时区处理**: 
   - 所有时间戳使用 UTC 存储
   - 显示时根据用户时区转换

## 🔄 用户状态转换

```
Active (活跃)
  ↓ 长时间未登录
Inactive (非活跃)
  ↓ 违规或其他原因
Suspended (暂停)
  ↓ 用户主动删除
Deleted (已删除)

或

Active (活跃)
  ↓ 重新激活
Inactive (非活跃)
  ↓ 恢复
Active (活跃)
```

## 🔐 密码安全最佳实践

### 密码加密

```rust
use bcrypt::{hash, verify, DEFAULT_COST};

// 注册时加密密码
let password_hash = hash("user_password", DEFAULT_COST)?;

// 登录时验证密码
let is_valid = verify("user_password", &stored_hash)?;
```

### 密码强度要求

建议实施以下密码策略：
- 最小长度 8 字符
- 包含大小写字母
- 包含数字
- 包含特殊字符
- 不能是常见密码

### 密码重置

```rust
// 1. 生成重置令牌
let reset_token = generate_secure_token();
let expires_at = Utc::now() + Duration::hours(24);

// 2. 存储令牌（使用独立的 password_resets 表）
// 3. 发送重置邮件
// 4. 用户点击链接后验证令牌
// 5. 更新密码
```

## 📊 用户统计查询

### 按角色统计

```rust
let role_stats = Users::find()
    .filter(users::Column::DeletedAt.is_null())
    .select_only()
    .column(users::Column::Role)
    .column_as(users::Column::SerialNum.count(), "count")
    .group_by(users::Column::Role)
    .into_json()
    .all(db)
    .await?;
```

### 活跃用户统计

```rust
let active_count = Users::find()
    .filter(users::Column::Status.eq("Active"))
    .filter(users::Column::DeletedAt.is_null())
    .filter(users::Column::LastActiveAt.gte(Utc::now() - Duration::days(30)))
    .count(db)
    .await?;
```

## 🔗 相关表

- [family_member - 家庭成员表](./family_member.md)
- [todo - 待办事项表](../business/todo.md)

## 📚 安全参考

- [OWASP 密码存储指南](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [bcrypt 文档](https://docs.rs/bcrypt/)
- [GDPR 隐私保护](https://gdpr.eu/)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
