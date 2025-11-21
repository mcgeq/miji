# TransactionModal 重构进度报告

## 📋 重构目标

将 TransactionModal 从自定义模态框结构重构为使用 BaseModal 组件，与其他 Modal 组件保持一致。

---

## ✅ 已完成的工作

### 1. 导入 BaseModal 组件 ✅
```typescript
import BaseModal from '@/components/common/BaseModal.vue';
```

### 2. 添加提交状态管理 ✅
```typescript
// 提交状态
const isSubmitting = ref(false);

// 模态框标题
const modalTitle = computed(() => {
  const titles: Record<TransactionType, string> = {
    Income: 'financial.transaction.recordIncome',
    Expense: 'financial.transaction.recordExpense',
    Transfer: 'financial.transaction.recordTransfer',
  };

  return props.transaction
    ? t('financial.transaction.editTransaction')
    : t(titles[props.type]);
});
```

### 3. 修改 handleSubmit 函数 ✅
- 添加了 `isSubmitting` 状态检查
- 添加了 `async/await` 支持
- 添加了 `try/finally` 块管理提交状态

```typescript
async function handleSubmit() {
  if (isSubmitting.value) return;

  // ... 验证逻辑 ...

  isSubmitting.value = true;
  try {
    await emitTransfer(amount);
    // 或 await emitTransaction(amount);
  } finally {
    isSubmitting.value = false;
  }
}
```

### 4. 删除不再需要的函数 ✅
- ❌ 删除了 `getModalTitle()` 函数（替换为 `modalTitle` 计算属性）
- ❌ 删除了 `handleOverlayClick()` 函数（BaseModal 会处理）

### 5. 修复代码问题 ✅
- 修复了重复的 `handleAmountInput` 函数定义
- 修复了函数参数问题

---

## 🚧 待完成的工作

### 1. 替换模板结构 ⏳ **当前任务**

需要将以下自定义结构：

```vue
<template>
  <div class="modal-mask" @click="handleOverlayClick">
    <div class="modal-mask-window-money" @click.stop>
      <div class="modal-header">
        <h2 class="modal-title">{{ getModalTitle() }}</h2>
        <button class="modal-close-btn" @click="$emit('close')">
          <!-- 关闭按钮 -->
        </button>
      </div>
      
      <form class="modal-form" @submit.prevent="handleSubmit">
        <!-- 表单内容 -->
        <div class="modal-actions">
          <button type="button" class="btn-close" @click="$emit('close')">
            <LucideX class="icon-btn" />
          </button>
          <button type="submit" class="btn-submit">
            <LucideCheck class="icon-btn" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
```

替换为：

```vue
<template>
  <BaseModal
    :title="modalTitle"
    size="lg"
    :confirm-loading="isSubmitting"
    :show-footer="!isReadonlyMode"
    @close="$emit('close')"
    @confirm="handleSubmit"
  >
    <form @submit.prevent="handleSubmit">
      <!-- 表单内容保持不变 -->
    </form>
  </BaseModal>
</template>
```

### 2. 修复模板中的函数调用 ⏳

需要修复以下错误：
- ❌ `handleOverlayClick` 不存在（已删除，BaseModal 会处理）
- ❌ `getModalTitle()` 不存在（改用 `modalTitle` 计算属性）
- ❌ `selectAllMembers` 不存在（需要添加或重命名）
- ❌ `clearMembers` 不存在（可能是 `clearMemberSelection`）

### 3. 清理自定义样式 ⏳

需要删除以下不再需要的样式：
- `.modal-mask`
- `.modal-mask-window-money`
- `.modal-header`
- `.modal-title`
- `.modal-close-btn`
- `.modal-actions`
- `.btn-close`
- `.btn-submit`

保留的样式：
- `.form-row`
- `.form-control`
- 其他表单相关样式

### 4. 测试验证 ⏳

需要测试以下功能：
- [ ] 创建收入交易
- [ ] 创建支出交易
- [ ] 创建转账交易
- [ ] 编辑现有交易
- [ ] 分期付款功能
- [ ] 费用分摊功能
- [ ] 家庭账本关联
- [ ] 表单验证
- [ ] 提交状态显示
- [ ] 键盘快捷键（ESC 关闭等）

---

## 🎯 重构挑战

### 1. 文件规模
- **行数**: 2264 行
- **复杂度**: 高（包含分期、分摊、账本关联等多个功能）
- **依赖**: 多个 composables 和工具函数

### 2. 特殊功能
- **分期付款**: 需要显示分期详情和计算
- **费用分摊**: 需要成员选择和分摊配置
- **账本关联**: 需要账本和成员的多选
- **只读模式**: 需要禁用所有输入和隐藏提交按钮

### 3. BaseModal 适配
- **尺寸**: 需要使用 `size="lg"` 以容纳复杂表单
- **底部按钮**: 需要根据只读模式动态显示/隐藏
- **自定义内容**: 大量的表单字段和条件渲染

---

## 📝 建议的实施步骤

### 步骤 1: 备份当前版本
```bash
git add src/features/money/components/TransactionModal.vue
git commit -m "WIP: TransactionModal refactoring - before template replacement"
```

### 步骤 2: 替换模板结构
1. 将 `<div class="modal-mask">` 替换为 `<BaseModal>`
2. 移除自定义的 header 和 footer
3. 保留所有表单内容不变
4. 添加 BaseModal 的必要属性

### 步骤 3: 修复模板中的引用
1. 将 `{{ getModalTitle() }}` 替换为 `{{ modalTitle }}`
2. 移除 `@click="handleOverlayClick"`
3. 修复 `selectAllMembers` 和 `clearMembers` 的引用

### 步骤 4: 清理样式
1. 删除不再需要的模态框样式
2. 保留表单相关样式
3. 调整可能冲突的样式

### 步骤 5: 测试验证
1. 测试所有交易类型的创建和编辑
2. 测试分期付款功能
3. 测试费用分摊功能
4. 测试只读模式

---

## ⚠️ 注意事项

### 1. BaseModal 的限制
- BaseModal 可能不支持某些自定义布局
- 需要确认 BaseModal 的 `size="lg"` 是否足够大
- 需要确认 BaseModal 是否支持自定义 footer

### 2. 向后兼容
- 确保所有现有功能正常工作
- 确保 API 调用不受影响
- 确保事件发射正常

### 3. 用户体验
- 确保模态框大小合适
- 确保滚动行为正常
- 确保键盘导航正常

---

## 🔄 替代方案

如果 BaseModal 不适合 TransactionModal 的复杂需求，可以考虑：

### 方案 A: 创建 TransactionBaseModal
创建一个专门的 TransactionBaseModal 组件，继承 BaseModal 但支持更多自定义：

```vue
<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
// 添加 TransactionModal 特定的功能
</script>

<template>
  <BaseModal v-bind="$attrs" size="xl">
    <template #header>
      <!-- 自定义 header -->
    </template>
    
    <slot />
    
    <template #footer>
      <!-- 自定义 footer -->
    </template>
  </BaseModal>
</template>
```

### 方案 B: 保持现状但优化
如果重构成本太高，可以：
1. 保持自定义模态框结构
2. 优化现有代码（已完成的部分保留）
3. 添加文档说明为什么不使用 BaseModal
4. 确保样式与其他 Modal 保持一致

---

## 📊 进度总结

| 任务 | 状态 | 完成度 |
|------|------|--------|
| 导入 BaseModal | ✅ 完成 | 100% |
| 添加状态管理 | ✅ 完成 | 100% |
| 修改提交逻辑 | ✅ 完成 | 100% |
| 删除旧函数 | ✅ 完成 | 100% |
| 修复代码问题 | ✅ 完成 | 100% |
| 替换模板结构 | 🚧 进行中 | 0% |
| 修复模板引用 | ⏳ 待开始 | 0% |
| 清理样式 | ⏳ 待开始 | 0% |
| 测试验证 | ⏳ 待开始 | 0% |

**总体进度**: 约 50%

---

## 🎯 下一步行动

1. **决策**: 确定是否继续使用 BaseModal 还是采用替代方案
2. **实施**: 如果继续，完成模板替换
3. **测试**: 全面测试所有功能
4. **文档**: 更新相关文档

---

**更新时间**: 2025-11-21  
**状态**: 🚧 进行中  
**负责人**: Miji Development Team
