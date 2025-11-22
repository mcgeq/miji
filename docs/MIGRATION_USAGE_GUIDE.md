# 新迁移文件使用指南

**更新时间**: 2025-11-22 17:10  
**状态**: ✅ lib.rs 已更新

---

## ✅ 已完成的操作

### 1. 备份旧文件
- ✅ 已将原 `lib.rs` 备份为 `lib_old_backup.rs`
- ✅ 位置: `src-tauri/migration/src/lib_old_backup.rs`

### 2. 更新 lib.rs
- ✅ 已替换为新的 lib.rs
- ✅ 注册了所有32个新迁移模块
- ✅ 按正确的依赖顺序排列

---

## 📋 新的迁移结构

### 模块组织
```rust
mod new {
    // 基础表 (1-4)
    pub mod m20251122_001_create_users;
    pub mod m20251122_002_create_currency;
    pub mod m20251122_003_create_account;
    pub mod m20251122_004_create_categories;
    
    // 业务核心表 (5-8)
    pub mod m20251122_005_create_sub_categories;
    pub mod m20251122_006_create_transactions;
    pub mod m20251122_007_create_budget;
    pub mod m20251122_008_create_budget_allocations;
    
    // ... 总共32个模块
}
```

### 迁移顺序
所有39个表按以下顺序迁移：
1. Users → Currency → Account → Categories → SubCategories
2. Transactions → Budget → BudgetAllocations
3. InstallmentPlans → InstallmentDetails
4. FamilyLedger → FamilyMember → 关联表
5. SplitRules → SplitRecords → 相关表
6. BilReminder
7. Todo系统 (Project → Tag → Todo → 关联表)
8. 通知系统
9. 健康周期系统
10. OperationLog

---

## 🚀 下一步操作

### 1. 编译验证
```bash
cd src-tauri/migration
cargo check
```

**预期结果**: 编译成功，无错误

---

### 2. 构建迁移
```bash
cd src-tauri/migration
cargo build
```

**预期结果**: 构建成功

---

### 3. 测试迁移（推荐在测试数据库）

#### 方式A: 使用 sea-orm-cli
```bash
# 安装 sea-orm-cli（如果还没有）
cargo install sea-orm-cli

# 运行迁移
cd src-tauri
sea-orm-cli migrate up -d sqlite://test.db
```

#### 方式B: 使用应用程序
```bash
# 启动应用程序，它会自动运行迁移
cd src-tauri
cargo run
```

---

### 4. 验证数据库

#### 检查表是否创建
```bash
# 使用 SQLite CLI
sqlite3 test.db ".tables"
```

**预期输出**: 应该看到所有39个表

#### 检查初始数据
```sql
-- 检查货币数据
SELECT * FROM currency;  -- 应该有10条

-- 检查分类数据
SELECT COUNT(*) FROM categories;  -- 应该有21条

-- 检查子分类数据
SELECT COUNT(*) FROM sub_categories;  -- 应该有130+条
```

---

## 🔧 故障排除

### 问题1: 编译错误 - 模块未找到

**可能原因**: 文件路径或命名不正确

**解决方案**:
```bash
# 检查所有文件是否存在
ls src-tauri/migration/src/new/
```

确保所有32个文件都存在且命名正确。

---

### 问题2: 外键约束错误

**可能原因**: 表的创建顺序不正确

**解决方案**: 
检查 lib.rs 中的迁移顺序，确保被依赖的表先创建。
当前顺序已经过验证，应该正确。

---

### 问题3: 初始数据插入失败

**可能原因**: 数据格式或约束问题

**解决方案**:
1. 检查 Currency 表的初始数据（10条）
2. 检查 Categories 表的初始数据（21条）
3. 检查 SubCategories 表的初始数据（130+条）

---

### 问题4: 唯一约束冲突

**可能原因**: 数据库中已有旧数据

**解决方案**:
```bash
# 删除旧数据库，重新运行迁移
rm test.db
sea-orm-cli migrate up -d sqlite://test.db
```

---

## 📊 验证清单

### 编译验证
- [ ] `cargo check` 通过
- [ ] `cargo build` 成功
- [ ] 无警告或错误

### 迁移验证
- [ ] 所有39个表成功创建
- [ ] 所有外键约束正确
- [ ] 所有索引创建成功

### 数据验证
- [ ] Currency: 10条数据
- [ ] Categories: 21条数据
- [ ] SubCategories: 130+条数据
- [ ] 所有初始数据完整

### 功能验证
- [ ] 应用程序启动成功
- [ ] 可以创建账户
- [ ] 可以创建交易
- [ ] 可以创建预算
- [ ] 可以创建待办事项

---

## 🔄 回滚方案（如果需要）

如果新迁移有问题，可以回滚到旧版本：

```bash
cd src-tauri/migration/src

# 恢复旧的 lib.rs
Copy-Item "lib_old_backup.rs" "lib.rs" -Force

# 重新编译
cargo clean
cargo build
```

---

## 📝 文件对照表

### 旧迁移文件（保留在 src/ 目录）
- 60+ 个迁移文件
- 分散的字段定义
- 多次 ALTER TABLE

### 新迁移文件（在 src/new/ 目录）
- 32 个迁移文件
- 整合的字段定义
- 一次性创建完整表

### 对照关系
请参考以下文档了解详细对照：
- `MIGRATION_REFACTOR_ANALYSIS.md` - 原始分析
- `MIGRATION_COMPLETE_SUMMARY.md` - 完整对照表

---

## 🎯 预期结果

### 成功标志
1. ✅ 编译无错误
2. ✅ 所有表创建成功
3. ✅ 初始数据完整
4. ✅ 应用程序正常运行
5. ✅ 所有功能可用

### 性能提升
- ✅ 迁移速度更快（减少 ALTER TABLE）
- ✅ 数据库结构更清晰
- ✅ 维护更容易

---

## 💡 注意事项

### 生产环境部署
⚠️ **重要**: 在生产环境部署前：

1. **备份数据库**
   ```bash
   # 备份现有数据库
   cp production.db production_backup_$(date +%Y%m%d).db
   ```

2. **测试迁移**
   - 在测试环境完整测试
   - 验证所有功能
   - 确认数据完整性

3. **准备回滚方案**
   - 保留旧的迁移文件
   - 准备数据库恢复脚本
   - 文档化回滚步骤

4. **灰度发布**
   - 先在小范围用户测试
   - 监控错误日志
   - 逐步扩大范围

---

## 📞 支持

如果遇到问题，请参考：
1. `MIGRATION_FINAL_REPORT.md` - 最终报告
2. `MIGRATION_COMPREHENSIVE_VERIFICATION.md` - 验证报告
3. `MIGRATION_CRITICAL_FIXES_NEEDED.md` - 修正记录

---

**更新人**: Cascade AI  
**更新时间**: 2025-11-22 17:10  
**版本**: 1.0  
**状态**: ✅ 准备就绪
