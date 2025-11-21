# FormRow 组件使用注意事项

## 📋 适用场景

FormRow 组件适合用于**标准的输入字段**，但并非所有表单元素都适合使用。

---

## ✅ 适合使用 FormRow 的场景

### 1. 标准输入框
```vue
<FormRow label="账户名称" required>
  <input v-model="form.name" class="modal-input-select w-full" />
</FormRow>
```

### 2. 标准选择框
```vue
<FormRow label="账户类型" required>
  <select v-model="form.type" class="modal-input-select w-full">
    <option value="BankSavings">银行储蓄</option>
  </select>
</FormRow>
```

### 3. 简单的数字输入
```vue
<FormRow label="初始余额" required>
  <input v-model="form.balance" type="number" class="modal-input-select w-full" />
</FormRow>
```

---

## ❌ 不适合使用 FormRow 的场景

### 1. 复杂的自定义组件

**问题**: ColorSelector 等自定义组件有自己的布局逻辑

**❌ 不推荐**:
```vue
<FormRow label="颜色">
  <ColorSelector v-model="formColor" />
</FormRow>
```

**✅ 推荐**: 使用原有的布局
```vue
<div class="form-row">
  <label class="form-label">{{ t('common.misc.color') }}</label>
  <div class="form-input-2-3">
    <ColorSelector v-model="formColor" />
  </div>
</div>
```

### 2. 大型文本域（需要隐藏 label）

**问题**: 文本域通常占据整行，不需要显示 label

**❌ 不推荐**:
```vue
<FormRow label="描述" optional>
  <textarea v-model="form.description" rows="3" />
</FormRow>
```

**✅ 推荐**: 使用独立布局
```vue
<div class="form-textarea">
  <textarea 
    v-model="form.description" 
    rows="3"
    class="modal-input-select w-full"
    :placeholder="`${t('common.misc.description')}（${t('common.misc.optional')}）`"
  />
  <span v-if="errors.description" class="form-error">{{ errors.description }}</span>
</div>
```

### 3. 复选框组

**问题**: 复选框通常需要特殊的布局

**❌ 不推荐**:
```vue
<FormRow label="选项">
  <input type="checkbox" v-model="form.isActive" />
</FormRow>
```

**✅ 推荐**: 使用专门的复选框布局
```vue
<div class="checkbox-row">
  <div class="checkbox-group">
    <label class="checkbox-label">
      <input type="checkbox" v-model="form.isShared" />
      <span>共享</span>
    </label>
  </div>
</div>
```

---

## 🎯 判断标准

### 使用 FormRow 的条件

✅ **应该使用** FormRow 当：
- 字段有明确的 label
- 输入控件是标准的 input/select
- 需要统一的布局和间距
- 需要显示错误提示

❌ **不应该使用** FormRow 当：
- 使用复杂的自定义组件
- 需要隐藏 label
- 需要特殊的布局
- 有多个控件在同一行

---

## 📝 最佳实践

### 1. 混合使用

在同一个表单中，可以混合使用 FormRow 和传统布局：

```vue
<form>
  <!-- 标准字段使用 FormRow -->
  <FormRow label="账户名称" required>
    <input v-model="form.name" class="modal-input-select w-full" />
  </FormRow>

  <FormRow label="账户类型" required>
    <select v-model="form.type" class="modal-input-select w-full">
      <option value="BankSavings">银行储蓄</option>
    </select>
  </FormRow>

  <!-- 复杂组件使用传统布局 -->
  <div class="form-row">
    <label class="form-label">颜色</label>
    <div class="form-input-2-3">
      <ColorSelector v-model="formColor" />
    </div>
  </div>

  <!-- 文本域使用独立布局 -->
  <div class="form-textarea">
    <textarea 
      v-model="form.description" 
      :placeholder="t('common.misc.description')"
    />
  </div>
</form>
```

### 2. 保持样式一致

即使不使用 FormRow，也要保持相同的样式类名和结构：

```vue
<!-- 保持一致的类名 -->
<div class="form-row">
  <label class="form-label">...</label>
  <div class="form-input-2-3">...</div>
</div>
```

### 3. 添加必要的样式

如果使用传统布局，确保在组件的 `<style>` 中定义必要的样式：

```vue
<style scoped>
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
}

.form-label {
  font-size: 0.875rem;
  font-weight: 500;
  width: 6rem;
  min-width: 6rem;
}

.form-input-2-3 {
  width: 66%;
}

.form-textarea {
  margin-bottom: 0.75rem;
}
</style>
```

---

## 🔄 AccountModal 示例

### 完整的混合使用示例

```vue
<template>
  <BaseModal>
    <form>
      <!-- ✅ 使用 FormRow: 标准输入框 -->
      <FormRow label="账户名称" required :error="errors.name">
        <input v-model="form.name" class="modal-input-select w-full" />
      </FormRow>

      <!-- ✅ 使用 FormRow: 标准选择框 -->
      <FormRow label="账户类型" required>
        <select v-model="form.type" class="modal-input-select w-full">
          <option value="BankSavings">银行储蓄</option>
        </select>
      </FormRow>

      <!-- ✅ 使用 FormRow: 数字输入 -->
      <FormRow label="初始余额" required>
        <input v-model="form.balance" type="number" class="modal-input-select w-full" />
      </FormRow>

      <!-- ❌ 不使用 FormRow: 复选框组 -->
      <div class="checkbox-row">
        <div class="checkbox-group">
          <label class="checkbox-label">
            <input type="checkbox" v-model="form.isShared" />
            <span>共享</span>
          </label>
        </div>
      </div>

      <!-- ❌ 不使用 FormRow: 复杂组件 -->
      <div class="form-row">
        <label class="form-label">颜色</label>
        <div class="form-input-2-3">
          <ColorSelector v-model="formColor" />
        </div>
      </div>

      <!-- ❌ 不使用 FormRow: 大型文本域 -->
      <div class="form-textarea">
        <textarea 
          v-model="form.description" 
          rows="3"
          :placeholder="`描述（可选）`"
        />
      </div>
    </form>
  </BaseModal>
</template>
```

---

## 📊 使用统计

### AccountModal 中的使用情况

| 字段 | 使用 FormRow | 原因 |
|------|-------------|------|
| 账户名称 | ✅ 是 | 标准输入框 |
| 账户类型 | ✅ 是 | 标准选择框 |
| 初始余额 | ✅ 是 | 数字输入 |
| 货币 | ✅ 是 | 标准选择框 |
| 所有者 | ✅ 是 | 标准选择框 |
| 共享/激活 | ❌ 否 | 复选框组 |
| 颜色 | ❌ 否 | 复杂组件 |
| 描述 | ❌ 否 | 大型文本域 |

**使用率**: 5/8 (62.5%)

---

## 🎯 总结

### 核心原则

1. **简单优先**: 标准字段使用 FormRow
2. **灵活处理**: 复杂场景使用传统布局
3. **保持一致**: 统一的样式和间距
4. **实用主义**: 不强求 100% 使用 FormRow

### 预期效果

- ✅ 减少重复代码
- ✅ 提高开发效率
- ✅ 保持样式一致
- ✅ 灵活应对特殊需求

---

**创建日期**: 2025-11-21  
**最后更新**: 2025-11-21  
**维护者**: Miji Development Team
