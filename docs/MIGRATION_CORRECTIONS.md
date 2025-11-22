# 迁移文件修正记录

**修正时间**: 2025-11-22 16:50

---

## 修正内容

### Transactions表 - 删除废弃字段

**问题**: 创建的Transactions表包含了 `SplitMembers` 字段，但该字段在后续迁移中被删除。

**修正**: 
1. 删除了 `SplitMembers` 字段定义（第76-78行）
2. 添加注释说明废弃字段（第75行）

**涉及的迁移文件**:
- `m20251116_drop_split_members.rs` - 删除 split_members 字段
- `m20251117_000001_remove_split_config_use_tables.rs` - 删除 split_config 字段

**修正后的Transactions表**:
```rust
// 不包含以下废弃字段：
// ❌ split_members (JSON) - 已废弃
// ❌ split_config (JSON) - 已废弃
// ✅ 使用独立的 split_records 和 split_record_details 表
```

---

## 废弃字段说明

### 1. `split_members` 字段
- **类型**: JSON
- **废弃原因**: 所有历史数据为空，改用独立表提升性能
- **删除时间**: 2025-11-16
- **替代方案**: `split_records` 表

### 2. `split_config` 字段  
- **类型**: JSON
- **废弃原因**: 改用独立表存储，提升查询性能和数据完整性
- **删除时间**: 2025-11-17
- **替代方案**: `split_records` + `split_record_details` 表

---

## 重构原则确认

在重构迁移文件时，应该：
- ✅ 只包含最终状态的字段
- ✅ 不包含中间过程添加但后续被删除的字段
- ✅ 添加注释说明历史变更原因
- ✅ 保持与当前代码库一致

---

## 验证清单

- [x] Transactions表不包含 `split_members`
- [x] Transactions表不包含 `split_config`  
- [x] 已添加注释说明废弃原因
- [x] split_records 表正确创建
- [x] split_record_details 表正确创建
- [x] 文档已更新说明

---

## 相关表

费用分摊功能现在使用以下独立表：

1. **split_records** (主表)
   - 文件: `m20251122_017_create_split_records.rs`
   - 存储: 分摊记录、金额、状态、类型等

2. **split_record_details** (详情表)
   - 文件: `m20251122_018_create_split_record_details.rs`  
   - 存储: 每个成员的分摊详情（金额、百分比、权重等）

3. **split_rules** (规则表)
   - 文件: `m20251122_016_create_split_rules.rs`
   - 存储: 分摊规则模板和配置

---

## 参考文档

- `MIGRATION_COMPLETE_SUMMARY.md` - 完整总结
- `MIGRATION_STATUS.md` - 实时状态（已更新）
- `SPLIT_RECORDS_USAGE.md` - 费用分摊使用指南（如果存在）

---

**状态**: ✅ 已修正  
**影响**: 无（仅删除了不应存在的字段）
