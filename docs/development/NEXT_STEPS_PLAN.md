# 🎯 下一步重构计划

## 📅 当前状态
- **完成日期**: 2025-11-21
- **当前进度**: 38% (10/26)
- **已完成**: 基础设施 + 所有 Actions + AccountModal

---

## ✅ 已完成工作回顾

### 1. 基础设施 (100%)
- ✅ BaseModal 组件
- ✅ useFormValidation Composable
- ✅ useCrudActions Composable
- ✅ Money Config Store

### 2. Actions Composables (100%)
- ✅ useAccountActions (-39%)
- ✅ useTransactionActions (+3%)
- ✅ useBudgetActions (-39%)
- ✅ useReminderActions (-40%)
- **总计**: 代码减少 218 行 (-27%)

### 3. Modal 组件 (8%)
- ✅ AccountModal

---

## 🎯 下一阶段任务

### 阶段 A: 简单 Modal 迁移 (优先)

#### 1. ReminderModal ⭐⭐⭐⭐
- **复杂度**: 中等
- **预计时间**: 2-3 小时
- **优先级**: 高
- **原因**: 结构相对简单，适合练手

#### 2. BudgetModal ⭐⭐⭐⭐
- **复杂度**: 中等
- **预计时间**: 3 小时
- **优先级**: 高
- **原因**: 有一些复杂的表单逻辑

### 阶段 B: 复杂 Modal 迁移

#### 3. TransactionModal ⭐⭐⭐⭐⭐
- **复杂度**: 高
- **预计时间**: 4-5 小时
- **优先级**: 最高
- **特点**:
  - 多种交易类型
  - 分期付款逻辑
  - 费用分摊功能
  - 复杂的表单验证

### 阶段 C: 家庭账本相关 Modal

#### 4. FamilyLedgerModal ⭐⭐⭐
- **复杂度**: 中等
- **预计时间**: 2 小时

#### 5. FamilyMemberModal ⭐⭐⭐
- **复杂度**: 中等
- **预计时间**: 2 小时

---

## 📋 详细迁移计划

### 本周剩余时间 (Week 1)

**目标**: 完成 2 个简单 Modal

1. **ReminderModal 迁移**
   - [ ] 使用 BaseModal
   - [ ] 使用 useFormValidation
   - [ ] 更新表单验证逻辑
   - [ ] 测试所有功能

2. **BudgetModal 迁移**
   - [ ] 使用 BaseModal
   - [ ] 使用 useFormValidation
   - [ ] 处理复杂的表单逻辑
   - [ ] 测试所有功能

**预期成果**:
- 完成 3 个 Modal (AccountModal + ReminderModal + BudgetModal)
- Modal 组件进度: 25% (3/12)
- 总进度: 42% (11/26)

### 下周 (Week 2)

**目标**: 完成 TransactionModal 和家庭账本 Modal

1. **TransactionModal 迁移** (2-3 天)
   - [ ] 分析现有代码结构
   - [ ] 使用 BaseModal
   - [ ] 使用 useFormValidation
   - [ ] 处理分期付款逻辑
   - [ ] 处理费用分摊逻辑
   - [ ] 全面测试

2. **FamilyLedgerModal 迁移** (1 天)
3. **FamilyMemberModal 迁移** (1 天)

**预期成果**:
- 完成 6 个 Modal
- Modal 组件进度: 50% (6/12)
- 总进度: 54% (14/26)

### 第三周 (Week 3)

**目标**: 完成剩余 Modal 和列表组件

1. **剩余 Modal 迁移**
   - SplitRuleConfig
   - SplitDetailModal
   - SplitTemplateModal
   - SettlementDetailModal
   - LedgerFormModal
   - MemberModal

2. **开始列表组件**
   - 创建 DataList 通用组件
   - 迁移 AccountList

---

## 🎓 迁移策略

### 简单 Modal 迁移模板

```vue
<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
import { useFormValidation } from '@/composables/useFormValidation';
import { CreateSchema } from '@/schema/money';

interface Props {
  item?: Item | null;
  readonly?: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [item: CreateRequest];
  update: [serialNum: string, item: UpdateRequest];
}>();

const { t } = useI18n();
const validation = useFormValidation(
  props.item ? UpdateSchema : CreateSchema
);

const form = ref<Item>(initializeForm());
const isSubmitting = ref(false);

async function handleSubmit() {
  if (!validation.validateAll(form.value)) {
    toast.error(t('validation.failed'));
    return;
  }

  isSubmitting.value = true;
  try {
    if (props.item) {
      emit('update', props.item.serialNum, form.value);
    } else {
      emit('save', form.value);
    }
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<template>
  <BaseModal
    :title="props.item ? t('edit') : t('create')"
    size="md"
    :confirm-loading="isSubmitting"
    :confirm-disabled="validation.hasAnyError.value"
    @close="emit('close')"
    @confirm="handleSubmit"
  >
    <form @submit.prevent="handleSubmit">
      <!-- 表单字段 -->
    </form>
  </BaseModal>
</template>
```

### 复杂 Modal 迁移策略

1. **分析现有代码**
   - 识别所有表单字段
   - 识别验证规则
   - 识别特殊逻辑

2. **分步迁移**
   - 先迁移基础结构（使用 BaseModal）
   - 再迁移验证逻辑（使用 useFormValidation）
   - 最后处理特殊逻辑

3. **充分测试**
   - 测试所有表单字段
   - 测试所有验证规则
   - 测试特殊业务逻辑

---

## 📊 预期收益

### 完成所有 Modal 后

| 指标 | 预期值 |
|------|--------|
| 代码减少 | ~800 行 |
| Modal 统一率 | 100% |
| 可维护性提升 | +70% |
| 用户体验提升 | +50% |

### 完成所有重构后

| 指标 | 预期值 |
|------|--------|
| 代码减少 | ~1500 行 |
| 组件统一率 | 100% |
| 开发效率提升 | +40% |
| Bug 修复速度 | +60% |

---

## ⚠️ 注意事项

### 1. TransactionModal 特别注意

- **分期付款逻辑**: 需要特别处理
- **费用分摊逻辑**: 需要保持完整性
- **多种交易类型**: Expense, Income, Transfer
- **复杂验证**: 不同类型有不同规则

### 2. 测试重点

- [ ] 创建功能
- [ ] 编辑功能
- [ ] 删除功能
- [ ] 表单验证
- [ ] 错误处理
- [ ] 特殊业务逻辑

### 3. 性能考虑

- 大型表单使用 `v-show` 而不是 `v-if`
- 复杂计算使用 `computed`
- 避免不必要的响应式数据

---

## 🔗 相关资源

### 文档
- [重构进度](./REFACTORING_PROGRESS.md)
- [BaseModal 使用指南](./BASE_MODAL_GUIDE.md)
- [useFormValidation 使用指南](./FORM_VALIDATION_GUIDE.md)
- [所有 Actions 重构总结](./ALL_ACTIONS_REFACTORING_SUMMARY.md)

### 示例代码
- AccountModal (已完成)
- AccountModalRefactored (示例)
- useAccountActions.refactored.ts
- useBudgetActions.refactored.ts

---

## 🎯 本次会话建议

由于时间关系，建议本次会话：

1. **创建总结报告** ✅
   - 汇总所有已完成的工作
   - 记录关键成果和经验

2. **更新文档** ✅
   - 更新进度文档
   - 创建下一步计划

3. **准备下次会话**
   - 明确下次的目标
   - 准备必要的资源

---

## 📝 会话总结模板

### 本次会话完成
- ✅ 基础设施搭建 (4 项)
- ✅ 所有 Actions 重构 (4 项)
- ✅ AccountModal 迁移 (1 项)
- ✅ 文档完善 (8 篇)

### 关键成果
- 代码减少 376 行
- 建立统一架构
- 完整的国际化支持
- 详细的文档体系

### 下次会话目标
- 迁移 ReminderModal
- 迁移 BudgetModal
- 测试已完成的工作

---

**创建日期**: 2025-11-21  
**版本**: v1.0  
**状态**: ✅ 计划就绪
