# 后端用户搜索功能部署指南

## 概述

本指南帮助你部署新实现的用户搜索后端API功能，并测试前端集成。

## 🚀 部署步骤

### 1. 验证后端代码更改

确认以下文件已正确修改：

#### ✅ 检查清单

- [ ] `src-tauri/crates/auth/src/dto/users.rs` - 添加了搜索DTO
- [ ] `src-tauri/crates/auth/src/services/user.rs` - 添加了搜索方法
- [ ] `src-tauri/crates/auth/src/commands.rs` - 添加了搜索命令
- [ ] `src-tauri/src/commands.rs` - 注册了新命令

### 2. 编译后端

```bash
# 进入后端目录
cd src-tauri

# 检查语法和依赖
cargo check

# 编译项目
cargo build
```

### 3. 数据库准备

确保数据库中有测试用户数据：

```sql
-- 创建测试用户（如果不存在）
INSERT INTO users (
    serial_num, name, email, password, 
    is_verified, role, status, created_at, updated_at
) VALUES 
    ('test_user_001', '测试用户1', 'test1@example.com', 'hashed_password', 
     true, '"User"', '"Active"', NOW(), NOW()),
    ('test_user_002', '张三', 'zhangsan@example.com', 'hashed_password', 
     true, '"User"', '"Active"', NOW(), NOW()),
    ('test_user_003', '李四', 'lisi@test.com', 'hashed_password', 
     true, '"Admin"', '"Active"', NOW(), NOW());

-- 更新最后活跃时间（用于测试最近用户功能）
UPDATE users 
SET last_active_at = NOW() - INTERVAL '1 day' 
WHERE email IN ('test1@example.com', 'zhangsan@example.com');
```

### 4. 启动应用

```bash
# 开发模式启动
npm run tauri dev

# 或者构建并运行
npm run tauri build
```

## 🧪 功能测试

### 1. 前端测试

在浏览器控制台中运行：

```javascript
// 导入测试工具（需要先在应用中导入）
import('/src/utils/testUserSearchApi.ts').then(module => {
  module.testUserSearchApis();
});
```

### 2. 手动测试步骤

#### ✅ 测试场景

1. **基础搜索测试**
   - [ ] 打开添加成员对话框
   - [ ] 选择"选择已有用户"模式
   - [ ] 输入用户姓名（如"张三"）
   - [ ] 验证显示匹配用户
   - [ ] 输入邮箱（如"test@"）
   - [ ] 验证显示匹配用户

2. **搜索历史测试**
   - [ ] 执行几次搜索
   - [ ] 重新打开搜索框
   - [ ] 验证显示搜索历史

3. **最近用户测试**
   - [ ] 打开搜索框（空输入状态）
   - [ ] 验证显示最近活跃用户列表

4. **缓存测试**
   - [ ] 搜索相同内容两次
   - [ ] 第二次应该更快（使用缓存）

5. **错误处理测试**
   - [ ] 搜索不存在的用户
   - [ ] 验证显示"未找到用户"

### 3. API直接测试

使用Tauri的开发者工具直接测试API：

```javascript
// 测试搜索用户
window.__TAURI__.invoke('search_users', {
  query: { keyword: '张三' },
  limit: 10
}).then(result => {
  console.log('搜索结果:', result);
}).catch(err => {
  console.error('搜索错误:', err);
});

// 测试最近用户
window.__TAURI__.invoke('list_recent_users', {
  limit: 5,
  days_back: 30
}).then(result => {
  console.log('最近用户:', result);
}).catch(err => {
  console.error('获取最近用户错误:', err);
});

// 测试根据ID获取用户
window.__TAURI__.invoke('get_user', {
  serial_num: 'test_user_001'
}).then(result => {
  console.log('用户详情:', result);
}).catch(err => {
  console.error('获取用户详情错误:', err);
});
```

## 🐛 故障排除

### 常见问题

#### 1. 编译错误

**错误**: `cannot find function search_users in this scope`

**解决**: 检查命令是否正确注册在 `src/commands.rs` 中

#### 2. API调用失败

**错误**: `Command search_users not found`

**解决**: 
- 确认应用已重新编译和启动
- 检查命令注册是否正确

#### 3. 搜索无结果

**错误**: 搜索返回空结果

**解决**:
- 检查数据库是否有测试数据
- 确认用户状态为Active且deleted_at为null
- 检查搜索条件是否正确

#### 4. 数据库连接错误

**错误**: `database connection failed`

**解决**:
- 检查数据库配置
- 确认数据库服务正在运行
- 验证连接字符串

### 调试技巧

#### 1. 启用详细日志

在 `src-tauri/.env` 中添加：

```env
RUST_LOG=debug
MIJI_LOG_LEVEL=debug
```

#### 2. 查看后端日志

```bash
# 查看Tauri应用日志
tail -f ~/.cache/miji/logs/app.log

# 或在开发模式下直接查看控制台输出
```

#### 3. 数据库查询验证

```sql
-- 验证用户数据
SELECT serial_num, name, email, status, deleted_at 
FROM users 
WHERE deleted_at IS NULL;

-- 验证搜索条件
SELECT * FROM users 
WHERE (name LIKE '%张%' OR email LIKE '%test%') 
AND deleted_at IS NULL;
```

## 📊 性能监控

### 1. 响应时间监控

```javascript
// 测试搜索性能
console.time('search_performance');
window.__TAURI__.invoke('search_users', {
  query: { keyword: 'test' },
  limit: 20
}).then(result => {
  console.timeEnd('search_performance');
  console.log(`返回${result.users.length}个结果`);
});
```

### 2. 缓存效果验证

```javascript
// 第一次搜索（无缓存）
console.time('first_search');
searchUsers('张三').then(() => {
  console.timeEnd('first_search');
  
  // 第二次搜索（使用缓存）
  console.time('cached_search');
  searchUsers('张三').then(() => {
    console.timeEnd('cached_search');
  });
});
```

## 🎯 性能基准

### 预期性能指标

- **搜索响应时间**: < 500ms（首次）
- **缓存命中响应**: < 50ms
- **最近用户加载**: < 200ms
- **单用户查询**: < 100ms

### 优化建议

如果性能不达标，考虑以下优化：

1. **数据库索引**:
```sql
-- 为搜索字段创建索引
CREATE INDEX idx_users_name ON users(name) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_active ON users(last_active_at DESC) WHERE deleted_at IS NULL;
```

2. **查询优化**:
- 限制搜索结果数量
- 使用分页查询
- 优化WHERE条件

3. **缓存策略**:
- 增加缓存时间
- 实现服务端缓存
- 使用查询结果预取

## ✅ 部署验收

部署完成后，确认以下功能正常：

- [ ] 用户可以通过姓名搜索到用户
- [ ] 用户可以通过邮箱搜索到用户  
- [ ] 搜索历史功能正常
- [ ] 最近用户显示正常
- [ ] 搜索缓存生效
- [ ] 错误处理合适
- [ ] 性能满足要求

## 🔄 版本回滚

如果出现问题需要回滚：

```bash
# 回到上一个git提交
git checkout HEAD~1

# 重新编译
npm run tauri build
```

前端会自动降级到旧的API调用方式，保证基本功能可用。
