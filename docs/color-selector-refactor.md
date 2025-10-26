# ColorSelector 组件重构说明

## 概述

ColorSelector 组件已经重构，支持更多颜色选择功能，同时保持完全的向后兼容性。

## 新功能

### 1. 扩展颜色调色板
- 新增 `EXTENDED_COLORS_MAP` 包含 40 种颜色
- 支持基础色、扩展色、柔和色、特殊色四个分类
- 通过 `extended` prop 启用

### 2. 颜色分类功能
- 支持按颜色类型分组显示
- 提供标签页切换不同颜色分类
- 通过 `showCategories` prop 启用

### 3. 自定义颜色选择器
- 支持手动输入十六进制颜色值
- 实时验证颜色格式
- 通过 `showCustomColor` prop 启用

### 4. 专业颜色选择器界面
- 类似 Photoshop 的专业颜色选择器界面
- 颜色预览区域显示当前选中颜色
- 十六进制和 RGB 输入框，支持复制功能
- 颜色渐变选择器（色相和饱和度）
- 色相滑块（彩虹色条）
- 基本颜色调色板
- 通过 `professional` prop 启用

## API 参考

### Props

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `modelValue` | `string` | - | 当前选中的颜色值（十六进制） |
| `colorNames` | `DefaultColors[]` | `COLORS_MAP` | 自定义颜色列表 |
| `extended` | `boolean` | `false` | 是否使用扩展颜色调色板 |
| `showCustomColor` | `boolean` | `true` | 是否显示自定义颜色选择器 |
| `showCategories` | `boolean` | `false` | 是否显示颜色分类标签 |
| `professional` | `boolean` | `false` | 是否使用专业颜色选择器界面 |

### Events

| 事件 | 参数 | 说明 |
|------|------|------|
| `update:modelValue` | `string` | 颜色值变化时触发 |

## 使用示例

### 基础用法（向后兼容）
```vue
<template>
  <ColorSelector v-model="selectedColor" />
</template>

<script setup>
import { ref } from 'vue';
import ColorSelector from '@/components/common/ColorSelector.vue';

const selectedColor = ref('#3B82F6');
</script>
```

### 扩展颜色调色板
```vue
<template>
  <ColorSelector 
    v-model="selectedColor" 
    :extended="true" 
  />
</template>
```

### 带颜色分类
```vue
<template>
  <ColorSelector 
    v-model="selectedColor" 
    :extended="true" 
    :show-categories="true" 
  />
</template>
```

### 自定义颜色选择器
```vue
<template>
  <ColorSelector 
    v-model="selectedColor" 
    :show-custom-color="true" 
  />
</template>
```

### 完整功能
```vue
<template>
  <ColorSelector 
    v-model="selectedColor" 
    :extended="true" 
    :show-categories="true" 
    :show-custom-color="true" 
  />
</template>
```

### 专业颜色选择器
```vue
<template>
  <ColorSelector 
    v-model="selectedColor" 
    :professional="true" 
  />
</template>
```

### 自定义颜色列表
```vue
<template>
  <ColorSelector 
    v-model="selectedColor" 
    :color-names="customColors" 
  />
</template>

<script setup>
import { ref } from 'vue';
import ColorSelector from '@/components/common/ColorSelector.vue';

const selectedColor = ref('#3B82F6');
const customColors = [
  { code: '#FF0000', nameZh: '红色', nameEn: 'Red' },
  { code: '#00FF00', nameZh: '绿色', nameEn: 'Green' },
  { code: '#0000FF', nameZh: '蓝色', nameEn: 'Blue' },
];
</script>
```

## 颜色分类

当启用 `extended` 和 `showCategories` 时，颜色将按以下分类显示：

- **基础色** (Basic): 10 种常用颜色
- **扩展色** (Extended): 10 种深色调颜色
- **柔和色** (Light): 10 种浅色调颜色
- **特殊色** (Special): 10 种特殊颜色

## 自定义颜色

当启用 `showCustomColor` 时，用户可以：

1. 点击"自定义颜色"按钮
2. 在输入框中输入十六进制颜色值（如 `#FF0000`）
3. 按回车键或点击"应用"按钮确认

支持的颜色格式：
- `#RRGGBB` (6位十六进制)
- `#RGB` (3位十六进制)

## 向后兼容性

所有现有的使用方式都完全兼容，无需修改任何代码：

```vue
<!-- 这些用法都继续有效 -->
<ColorSelector v-model="color" />
<ColorSelector v-model="color" :color-names="customColors" />
```

## 专业颜色选择器功能

当启用 `professional` prop 时，ColorSelector 将显示专业颜色选择器界面，包含：

### 左侧控制面板
1. **颜色预览区域** - 大尺寸显示当前选中的颜色
2. **十六进制输入框** - 支持手动输入和复制功能
3. **RGB 输入框** - 分别输入 R、G、B 值（0-255）
4. **基本颜色调色板** - 18 种常用颜色快速选择

### 右侧颜色选择区域
1. **颜色渐变选择器** - 200x200px 的色相和饱和度选择区域
   - 水平方向控制饱和度（0-100%）
   - 垂直方向控制亮度（0-100%）
   - 圆形手柄显示当前位置
2. **色相滑块** - 垂直的彩虹色条
   - 从上到下：红→橙→黄→绿→青→蓝→紫→红
   - 滑块位置控制色相（0-360°）

### 交互功能
- **拖拽选择** - 在渐变区域和色相滑块上拖拽选择颜色
- **实时预览** - 所有操作实时更新颜色预览和输入框
- **键盘输入** - 支持在输入框中直接输入颜色值
- **复制功能** - 点击复制按钮复制颜色值到剪贴板

## 在现有组件中启用更多颜色选择

如果您希望在现有的账户、预算、提醒等组件中使用更多颜色选择，只需要在 ColorSelector 组件上添加相应的 props：

### 启用扩展颜色调色板
```vue
<ColorSelector 
  v-model="form.color" 
  :color-names="colorNameMap" 
  :extended="true"
/>
```

### 启用颜色分类
```vue
<ColorSelector 
  v-model="form.color" 
  :color-names="colorNameMap" 
  :extended="true"
  :show-categories="true"
/>
```

### 启用自定义颜色选择
```vue
<ColorSelector 
  v-model="form.color" 
  :color-names="colorNameMap" 
  :extended="true"
  :show-categories="true"
  :show-custom-color="true"
/>
```

### 启用专业颜色选择器
```vue
<ColorSelector 
  v-model="form.color" 
  :professional="true"
/>
```

## 已更新的组件

以下组件已经更新为使用扩展颜色选择功能：
- `AccountModal.vue` - 账户创建/编辑
- `BudgetModal.vue` - 预算创建/编辑  
- `ReminderModal.vue` - 提醒创建/编辑

## 测试

可以通过访问 `/color-selector-test` 页面来测试所有新功能，包括专业颜色选择器。
