# 🎨 UI Components

基于 **Headless UI + Tailwind CSS 4** 的现代化 UI 组件库。

## 📦 已创建组件

### 核心组件

| 组件 | 描述 | 状态 |
|------|------|------|
| **Modal** | 模态框 | ✅ 完成 |
| **ConfirmDialog** | 确认对话框 | ✅ 完成 |
| **Dropdown** | 下拉菜单 | ✅ 完成 |
| **Tabs** | 标签页 | ✅ 完成 |
| **Button** | 按钮 | ✅ 完成 |
| **Tooltip** | 工具提示 | ✅ 完成 |

## 🚀 快速开始

### 导入方式

```typescript
// 批量导入
// 单个导入
```

### 使用示例

#### Modal

```vue
<script setup>
import { ref } from 'vue';
import { Modal } from '@/components/ui';

const isOpen = ref(false);
</script>

<template>
  <button @click="isOpen = true">
    打开
  </button>

  <Modal
    :open="isOpen"
    title="标题"
    @close="isOpen = false"
    @confirm="handleConfirm"
  >
    <p>内容</p>
  </Modal>
</template>
```

#### ConfirmDialog

```vue
<script setup>
import { ref } from 'vue';
import { ConfirmDialog } from '@/components/ui';

const isOpen = ref(false);
</script>

<template>
  <ConfirmDialog
    :open="isOpen"
    type="warning"
    title="确认删除"
    message="此操作不可撤销"
    @close="isOpen = false"
    @confirm="handleDelete"
  />
</template>
```

#### Button

```vue
<template>
  <Button variant="primary" size="md">
    点击我
  </Button>

  <Button variant="danger" :loading="isLoading">
    删除
  </Button>

  <Button variant="ghost" :icon="PlusIcon">
    添加
  </Button>
</template>
```

#### Dropdown

```vue
<script setup>
import { Dropdown } from '@/components/ui';

const options = [
  { value: '1', label: '选项 1' },
  { value: '2', label: '选项 2' },
  { value: '3', label: '选项 3' }
];

const selected = ref('1');
</script>

<template>
  <Dropdown
    v-model="selected"
    :options="options"
    label="选择选项"
    show-check
  />
</template>
```

#### Tabs

```vue
<script setup>
import { Tabs } from '@/components/ui';

const tabs = [
  { name: '标签 1', value: 'tab1' },
  { name: '标签 2', value: 'tab2' },
  { name: '标签 3', value: 'tab3', badge: 5 }
];
</script>

<template>
  <Tabs :tabs="tabs" variant="pills">
    <template #panel-0>
      内容 1
    </template>
    <template #panel-1>
      内容 2
    </template>
    <template #panel-2>
      内容 3
    </template>
  </Tabs>
</template>
```

## ✨ 组件特性

### 共同特性

- ✅ **100% Tailwind CSS 4** - 无自定义 CSS
- ✅ **完整可访问性** - 基于 Headless UI
- ✅ **键盘导航** - 完整支持
- ✅ **深色模式** - 自动适配
- ✅ **TypeScript** - 完整类型支持
- ✅ **响应式** - 移动端友好

### 对比优势

| 对比项 | 旧组件 (BaseModal) | 新组件 (Modal) |
|--------|-------------------|----------------|
| **代码量** | 414 行 | 220 行 (-47%) |
| **CSS** | 260 行 | 0 行 (-100%) |
| **可定制性** | 低 | 高 |
| **维护成本** | 高 | 低 |
| **可访问性** | 部分 | 完整 |

## 📖 组件文档

### Modal

**Props:**
- `open: boolean` - 是否显示
- `title?: string` - 标题
- `size?: 'sm' | 'md' | 'lg' | 'xl' | 'full'` - 尺寸
- `closeOnOverlay?: boolean` - 点击遮罩关闭
- `showHeader?: boolean` - 显示头部
- `showFooter?: boolean` - 显示底部

**Events:**
- `@close` - 关闭事件
- `@confirm` - 确认事件
- `@cancel` - 取消事件

**Slots:**
- `header` - 自定义头部
- `default` - 内容
- `footer` - 自定义底部

### ConfirmDialog

**Props:**
- `open: boolean` - 是否显示
- `type?: 'info' | 'success' | 'warning' | 'error'` - 类型
- `title: string` - 标题
- `message?: string` - 消息
- `loading?: boolean` - 加载状态

**Events:**
- `@close` - 关闭
- `@confirm` - 确认

### Button

**Props:**
- `variant?: 'primary' | 'secondary' | 'success' | 'danger' | 'ghost'` - 变体
- `size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl'` - 尺寸
- `loading?: boolean` - 加载状态
- `disabled?: boolean` - 禁用
- `icon?: Component` - 图标

### Dropdown

**Props:**
- `options: DropdownOption[]` - 选项列表
- `modelValue?: string` - 当前选中值
- `showCheck?: boolean` - 显示选中标记

**Events:**
- `@update:modelValue` - 值更新
- `@select` - 选中事件

### Tabs

**Props:**
- `tabs: TabItem[]` - 标签列表
- `modelValue?: number` - 当前选中索引
- `variant?: 'pills' | 'underline' | 'enclosed'` - 样式
- `vertical?: boolean` - 垂直排列

**Events:**
- `@update:modelValue` - 索引更新
- `@change` - 切换事件

## 🎯 最佳实践

### 1. 使用 Tailwind Utilities

```vue
<!-- ✅ 好 -->
<Modal :open="isOpen" class="custom-class">
  <div class="p-4 bg-blue-50 rounded-lg">
    内容
  </div>
</Modal>

<!-- ❌ 坏 -->
<Modal :open="isOpen" style="padding: 1rem;">
  ...
</Modal>
```

### 2. 组合组件

```vue
<!-- ✅ 好：组合多个组件 -->
<Modal :open="isOpen">
  <Tabs :tabs="tabs">
    <template #panel-0>
      <Button @click="handleAction">操作</Button>
    </template>
  </Tabs>
</Modal>
```

### 3. 使用插槽自定义

```vue
<!-- ✅ 完全自定义 -->
<Modal :open="isOpen" :show-footer="false">
  <template #header>
    <div class="flex items-center gap-2">
      <Icon />
      <span>自定义标题</span>
    </div>
  </template>

  <!-- 自定义内容 -->

  <!-- 自定义底部 -->
  <div class="flex justify-center gap-3 mt-4">
    <Button>自定义按钮</Button>
  </div>
</Modal>
```

## 🔧 开发指南

### 添加新组件

1. 在 `src/components/ui/` 创建新文件
2. 使用 Headless UI 提供逻辑
3. 使用 Tailwind CSS 4 提供样式
4. 在 `index.ts` 中导出

### 组件设计原则

1. **Headless First** - 逻辑与样式分离
2. **Tailwind Only** - 不创建自定义 CSS
3. **TypeScript** - 完整类型定义
4. **可访问性** - 遵循 ARIA 标准
5. **响应式** - 移动端优先

## 📝 注意事项

### IDE 警告

部分 IDE 可能显示 `'props' is declared but its value is never read` 警告，这是正常的，可以忽略。Props 在 Vue 模板中被使用。

### 深色模式

所有组件已自动适配深色模式，使用 `dark:` 变体即可。

### 动画性能

使用 `@media (prefers-reduced-motion: reduce)` 自动禁用动画，提升可访问性。

## 🚀 下一步

- [ ] 添加更多组件（Badge, Card, Alert 等）
- [ ] 创建 Storybook 文档
- [ ] 添加单元测试
- [ ] 性能优化

## 📚 参考

- [Headless UI Vue](https://headlessui.com/v1/vue)
- [Tailwind CSS 4](https://tailwindcss.com/docs)
- [WAI-ARIA](https://www.w3.org/WAI/ARIA/apg/)
