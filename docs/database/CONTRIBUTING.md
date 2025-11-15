# 数据库文档贡献指南

本文档说明如何为数据库表创建和维护文档。

## 📁 目录结构

```
docs/database/
├── README.md                    # 主索引文件
├── TEMPLATE.md                  # 文档模板
├── CONTRIBUTING.md              # 本文件
├── core/                        # 核心功能表
│   ├── family_ledger.md
│   ├── family_member.md
│   ├── account.md
│   ├── transactions.md
│   ├── currency.md
│   └── users.md
├── association/                 # 关联关系表
│   ├── family_ledger_member.md
│   ├── family_ledger_account.md
│   └── family_ledger_transaction.md
├── financial/                   # 财务管理表
│   ├── budget.md
│   ├── categories.md
│   ├── split_rules.md
│   └── ...
├── business/                    # 业务功能表
│   ├── todo.md
│   ├── reminder.md
│   └── ...
└── system/                      # 系统配置表
    ├── attachment.md
    ├── notification_settings.md
    └── ...
```

## 📝 创建新表文档

### 步骤 1: 确定分类

根据表的功能确定所属目录：

- **core/**: 核心业务实体（账本、成员、账户、交易等）
- **association/**: 多对多关联表
- **financial/**: 财务相关（预算、分类、分摊、结算等）
- **business/**: 其他业务功能（待办、提醒、生理期等）
- **system/**: 系统级配置和日志

### 步骤 2: 复制模板

```bash
cp docs/database/TEMPLATE.md docs/database/[category]/[table_name].md
```

### 步骤 3: 填写内容

参考 [TEMPLATE.md](./TEMPLATE.md) 和现有文档示例：
- [family_ledger.md](./core/family_ledger.md) - 核心表示例
- [family_member.md](./core/family_member.md) - 带财务字段的表
- [family_ledger_member.md](./association/family_ledger_member.md) - 关联表示例

### 步骤 4: 更新索引

在 [README.md](./README.md) 中添加新表的链接。

## 📋 文档内容要求

### 必需部分

1. **表信息**
   - 表名
   - 说明
   - 主键
   - 相关迁移文件

2. **表结构**
   - 所有字段的详细说明
   - 字段分组（基础、关联、统计等）
   - 枚举值（如有）
   - 用途说明

3. **关系说明**
   - 外键关系
   - 一对多关系
   - 多对多关系
   - 级联操作

4. **索引建议**
   - 主键索引
   - 外键索引
   - 业务查询索引

5. **使用示例**
   - 创建记录
   - 查询记录
   - 更新记录
   - 删除记录

6. **注意事项**
   - 重要的业务规则
   - 数据完整性要求
   - 常见陷阱

### 可选部分

- 业务流程说明
- 数据示例
- 状态转换图
- 计算逻辑
- 相关文档链接

## 🎨 格式规范

### 标题层级

```markdown
# 一级标题 - 表名
## 二级标题 - 主要部分
### 三级标题 - 子部分
#### 四级标题 - 详细说明（少用）
```

### 表格格式

```markdown
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| `field` | VARCHAR | NOT NULL | 说明 |
```

- 字段名使用反引号 `` `field_name` ``
- 类型使用大写 `VARCHAR`, `INTEGER`
- 约束使用缩写 `PK`, `FK`, `NOT NULL`

### 代码块

使用语言标识：

````markdown
```rust
// Rust 代码
```

```sql
-- SQL 代码
```

```json
{
  "key": "value"
}
```
````

### Emoji 使用

统一使用以下 emoji：

- 📋 表信息
- 📊 表结构
- 🔗 关系说明
- 📑 索引建议
- 💡 使用示例
- ⚠️ 注意事项
- 🔄 业务流程
- 📚 相关文档

## 🔍 信息来源

### 1. Entity 文件

位置：`src-tauri/entity/src/[table_name].rs`

包含信息：
- 字段定义
- 数据类型
- 关系定义
- 约束条件

### 2. 迁移文件

位置：`src-tauri/migration/src/m*.rs`

包含信息：
- 表创建 SQL
- 字段定义
- 索引定义
- 外键约束
- 默认值

### 3. Service 文件

位置：`src-tauri/crates/money/src/services/[table_name].rs`

包含信息：
- 业务逻辑
- 使用示例
- 注意事项

### 4. DTO 文件

位置：`src-tauri/crates/money/src/dto/[table_name].rs`

包含信息：
- API 接口字段
- 数据转换逻辑

## ✅ 文档检查清单

提交前请确认：

- [ ] 表信息完整（表名、主键、迁移文件）
- [ ] 所有字段都有说明
- [ ] 枚举值已列出
- [ ] 外键关系已说明
- [ ] 级联操作已标注
- [ ] 索引建议合理
- [ ] 至少有 2 个使用示例
- [ ] 注意事项不少于 3 条
- [ ] 相关表链接正确
- [ ] 返回索引链接正确
- [ ] 代码示例可运行
- [ ] 格式符合规范
- [ ] 已更新主索引文件

## 📊 优先级

按以下优先级创建文档：

### 高优先级（核心表）
1. family_ledger
2. family_member
3. account
4. transactions
5. currency

### 中优先级（关联和财务表）
6. family_ledger_member
7. family_ledger_account
8. family_ledger_transaction
9. split_rules
10. split_records
11. debt_relations
12. settlement_records
13. budget
14. categories

### 低优先级（其他表）
15. 其他业务表
16. 系统配置表

## 🔄 更新维护

### 何时更新文档

- 添加新字段
- 修改字段类型或约束
- 添加新索引
- 修改外键关系
- 业务逻辑变更
- 发现文档错误

### 更新流程

1. 修改对应的表文档
2. 更新"最后更新"日期
3. 如果是结构性变更，在文档中添加"历史变更"部分
4. 提交 PR 并说明变更原因

## 📚 参考资源

- [SeaORM 文档](https://www.sea-ql.org/SeaORM/)
- [SQLite 文档](https://www.sqlite.org/docs.html)
- [Markdown 语法](https://www.markdownguide.org/)
- [数据库设计最佳实践](../BEST_PRACTICES.md)

## 💬 问题反馈

如有疑问或建议，请：
1. 查看现有文档示例
2. 参考本指南
3. 提交 Issue 或 PR

---

**维护者**: Miji Team  
**最后更新**: 2025-11-15
