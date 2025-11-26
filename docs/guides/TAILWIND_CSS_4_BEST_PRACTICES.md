# 🎨 Tailwind CSS 4 最佳实践

> **重要更新：** Tailwind CSS 4 废弃了 `@layer` 和 `@apply`，引入了 `@utility` 和 `@theme` 等现代化指令

## 🚫 已废弃的用法

### ❌ 不要使用 @layer + @apply

```css
/* ❌ Tailwind CSS 3 的旧方式 - 已废弃 */
@layer base {
  body {
    @apply bg-white text-gray-900;
  }
}

@layer components {
  .btn-primary {
    @apply bg-blue-600 text-white px-4 py-2 rounded-lg;
  }
}
```

**问题：**
1. `@apply` 导致构建时性能下降
2. 破坏了 utility-first 的理念
3. 增加了不必要的抽象层
4. 难以追踪样式来源

---

## ✅ Tailwind CSS 4 推荐用法

### 1. 使用 @theme 定义设计令牌

```css
/* ✅ 正确：使用 @theme 定义设计系统 */
@import "tailwindcss";

@theme {
  /* 颜色 - 使用语义化命名 */
  --color-primary: #3b82f6;
  --color-primary-hover: #2563eb;
  --color-success: #10b981;
  --color-warning: #f59e0b;
  --color-error: #ef4444;
  
  /* 间距 - 扩展默认间距 */
  --spacing-18: 4.5rem;
  --spacing-88: 22rem;
  
  /* 字体 */
  --font-sans: system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  
  /* 圆角 */
  --radius-xl: 1rem;
  --radius-2xl: 1.5rem;
  
  /* 阴影 */
  --shadow-glow: 0 0 20px rgba(59, 130, 246, 0.5);
  
  /* 动画时长 */
  --duration-fast: 150ms;
  --duration-normal: 200ms;
  --duration-slow: 300ms;
}
```

### 2. 使用原生 CSS 定义全局样式

```css
/* ✅ 正确：使用原生 CSS */
body {
  margin: 0;
  font-family: var(--font-sans);
  background-color: light-dark(white, #0f172a);
  color: light-dark(#0f172a, white);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* 滚动条样式 */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: light-dark(#f1f5f9, #1e293b);
}

::-webkit-scrollbar-thumb {
  background: light-dark(#cbd5e1, #475569);
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: light-dark(#94a3b8, #64748b);
}
```

### 3. 使用 @utility 创建自定义 Utilities ⭐

Tailwind CSS 4 引入了 `@utility` 指令，用于创建自定义 utility classes。

```css
/* ✅ 正确：使用 @utility 创建自定义工具类 */

/* 单个 utility */
@utility bg-grid {
  background-image: 
    linear-gradient(to right, rgb(0 0 0 / 0.05) 1px, transparent 1px),
    linear-gradient(to bottom, rgb(0 0 0 / 0.05) 1px, transparent 1px);
  background-size: 20px 20px;
}

/* 带变体的 utility */
@utility center-flex {
  display: flex;
  align-items: center;
  justify-content: center;
}

/* 响应式 utility */
@utility text-balance {
  text-wrap: balance;
}

/* 自定义动画 */
@utility animate-fade-in {
  animation: fade-in 200ms ease-out;
}

/* 组合多个样式 */
@utility card-shadow {
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
  border-radius: 0.5rem;
}
```

#### 使用自定义 utility

```vue
<template>
  <!-- 直接使用自定义 utility -->
  <div class="bg-grid p-8">
    <div class="center-flex h-64">
      <h1 class="text-balance">标题文本</h1>
    </div>
  </div>
  
  <!-- 结合 Tailwind 内置 utilities -->
  <div class="card-shadow p-6 bg-white dark:bg-gray-800">
    卡片内容
  </div>
</template>
```

#### @utility vs @apply 对比

| 特性 | @apply (已废弃) | @utility (推荐) |
|------|----------------|----------------|
| **性能** | 慢（构建时处理） | 快（直接生成） |
| **语法** | 复杂（需要 @layer） | 简洁（单一指令） |
| **可维护性** | 差（样式分散） | 好（集中定义） |
| **变体支持** | 自动支持 | 自动支持 |
| **Tree-shaking** | 部分支持 | 完全支持 |

```css
/* ❌ 旧方式：@layer + @apply */
@layer utilities {
  .btn-primary {
    @apply bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700;
  }
}

/* ✅ 新方式：@utility */
@utility btn-primary {
  background-color: #3b82f6;
  color: white;
  padding: 1rem 1.5rem;
  border-radius: 0.5rem;
  
  &:hover {
    background-color: #2563eb;
  }
}
```

#### 实际应用场景

```css
/* ✅ 创建项目特定的 utilities */

/* 1. 自定义渐变背景 */
@utility gradient-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

/* 2. 自定义文本样式 */
@utility text-glow {
  text-shadow: 0 0 10px currentColor;
}

/* 3. 自定义边框效果 */
@utility border-gradient {
  border: 2px solid transparent;
  background-clip: padding-box;
  background-image: linear-gradient(white, white), 
                    linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  background-origin: border-box;
}

/* 4. 自定义滚动效果 */
@utility scroll-smooth {
  scroll-behavior: smooth;
  scroll-padding-top: 2rem;
}

/* 5. 玻璃态效果 */
@utility glass {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
}
```

### 4. 使用 light-dark() 函数实现主题切换

```css
/* ✅ Tailwind CSS 4 的现代主题切换 */
.card {
  background-color: light-dark(white, #1e293b);
  border-color: light-dark(#e2e8f0, #334155);
  color: light-dark(#0f172a, #f8fafc);
}

/* 自动跟随系统主题 */
html[data-theme="auto"] {
  color-scheme: light dark;
}

/* 强制浅色主题 */
html[data-theme="light"] {
  color-scheme: light;
}

/* 强制深色主题 */
html[data-theme="dark"] {
  color-scheme: dark;
}
```

### 4. 定义可复用的动画

```css
/* ✅ 使用原生 @keyframes */
@keyframes fade-in {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes slide-up {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes scale-in {
  from {
    opacity: 0;
    transform: scale(0.95);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

/* 在 @theme 中引用 */
@theme {
  --animate-fade-in: fade-in 200ms ease-out;
  --animate-slide-up: slide-up 300ms ease-out;
  --animate-scale-in: scale-in 200ms cubic-bezier(0.16, 1, 0.3, 1);
}
```

### 5. 直接在 HTML 中使用 Tailwind Classes

```vue
<!-- ✅ 正确：直接使用 utility classes -->
<template>
  <button
    class="
      px-4 py-2 rounded-lg
      bg-blue-600 text-white
      hover:bg-blue-700
      active:bg-blue-800
      focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
      disabled:opacity-50 disabled:cursor-not-allowed
      transition-colors duration-200
      dark:bg-blue-500 dark:hover:bg-blue-600
    "
  >
    按钮
  </button>
</template>
```

### 6. 使用组合而非自定义类

```vue
<!-- ❌ 错误：创建自定义类 -->
<style>
.btn-primary {
  @apply bg-blue-600 text-white px-4 py-2 rounded-lg;
}
</style>

<button class="btn-primary">按钮</button>
```

```vue
<!-- ✅ 正确：使用 Vue 组件组合 -->
<script setup lang="ts">
const buttonClasses = 'px-4 py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors'
</script>

<template>
  <button :class="buttonClasses">按钮</button>
</template>
```

```vue
<!-- ✅ 更好：创建可复用的 Button 组件 -->
<script setup lang="ts">
interface Props {
  variant?: 'primary' | 'secondary' | 'danger'
  size?: 'sm' | 'md' | 'lg'
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  size: 'md'
})

const variantClasses = {
  primary: 'bg-blue-600 hover:bg-blue-700 text-white',
  secondary: 'bg-gray-200 hover:bg-gray-300 text-gray-900',
  danger: 'bg-red-600 hover:bg-red-700 text-white'
}

const sizeClasses = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-6 py-3 text-lg'
}
</script>

<template>
  <button
    :class="[
      'rounded-lg font-medium transition-colors',
      'focus:outline-none focus:ring-2 focus:ring-offset-2',
      'disabled:opacity-50 disabled:cursor-not-allowed',
      variantClasses[variant],
      sizeClasses[size]
    ]"
  >
    <slot />
  </button>
</template>
```

---

## 🎯 最佳实践总结

### 1. 设计令牌优先

```css
/* ✅ 在 @theme 中定义 */
@theme {
  --color-brand: #3b82f6;
}

/* ✅ 在 HTML 中使用 */
<div class="bg-[--color-brand]">
```

### 2. 使用 CSS 变量而非硬编码

```vue
<!-- ❌ 硬编码颜色 -->
<div class="bg-[#3b82f6]">

<!-- ✅ 使用变量 -->
<div class="bg-[--color-primary]">
```

### 3. 利用 Tailwind 的变体系统

```vue
<button class="
  bg-blue-600
  hover:bg-blue-700
  active:bg-blue-800
  focus:ring-2
  disabled:opacity-50
  dark:bg-blue-500
  dark:hover:bg-blue-600
  motion-safe:transition-colors
  motion-reduce:transition-none
">
  完整的状态支持
</button>
```

### 4. 使用容器查询（Tailwind CSS 4 新特性）

```vue
<div class="@container">
  <div class="
    grid grid-cols-1
    @sm:grid-cols-2
    @md:grid-cols-3
    @lg:grid-cols-4
  ">
    <!-- 根据容器大小响应，而非视口大小 -->
  </div>
</div>
```

### 5. 使用子网格（Tailwind CSS 4 新特性）

```vue
<div class="grid grid-cols-3 gap-4">
  <div class="col-span-3 grid subgrid">
    <!-- 继承父网格的列定义 -->
  </div>
</div>
```

---

## 📋 迁移清单

从 Tailwind CSS 3 迁移到 4：

### 需要移除
- [ ] 删除所有 `@layer base { }` 代码
- [ ] 删除所有 `@layer components { }` 代码
- [ ] 删除所有 `@layer utilities { }` 代码
- [ ] 删除所有 `@apply` 指令
- [ ] 移除 `tailwind.config.js` 中的 `theme.extend`

### 需要更新
- [ ] 将自定义颜色移至 `@theme { }`
- [ ] 将全局样式改为原生 CSS
- [ ] 使用 `light-dark()` 替代 `dark:` 变体（可选）
- [ ] 更新 PostCSS 配置（简化或移除）

### 需要添加
- [ ] 定义 `@theme { }` 设计令牌
- [ ] 定义 `@keyframes` 动画
- [ ] 使用 `@utility` 创建项目特定的工具类（可选）
- [ ] 创建可复用的 Vue 组件而非 CSS 类

---

## 🔧 完整示例

### 推荐的 index.css 结构

```css
/* src/assets/styles/index.css */

/* 导入 Tailwind */
@import "tailwindcss";

/* ========================================
   设计令牌
   ======================================== */
@theme {
  /* 颜色系统 */
  --color-primary: #3b82f6;
  --color-primary-hover: #2563eb;
  --color-primary-active: #1d4ed8;
  
  --color-success: #10b981;
  --color-warning: #f59e0b;
  --color-error: #ef4444;
  --color-info: #06b6d4;
  
  /* 背景色 */
  --color-bg-base: light-dark(white, #0f172a);
  --color-bg-elevated: light-dark(#f8fafc, #1e293b);
  
  /* 文本色 */
  --color-text-primary: light-dark(#0f172a, #f8fafc);
  --color-text-secondary: light-dark(#64748b, #cbd5e1);
  
  /* 边框色 */
  --color-border: light-dark(#e2e8f0, #334155);
  
  /* 字体 */
  --font-sans: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;
  
  /* 圆角 */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
  
  /* 阴影 */
  --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  
  /* 动画 */
  --animate-fade-in: fade-in 200ms ease-out;
  --animate-fade-out: fade-out 150ms ease-in;
  --animate-slide-up: slide-up 300ms ease-out;
  --animate-scale-in: scale-in 200ms cubic-bezier(0.16, 1, 0.3, 1);
}

/* ========================================
   全局样式
   ======================================== */
* {
  box-sizing: border-box;
}

html {
  color-scheme: light dark;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

body {
  margin: 0;
  font-family: var(--font-sans);
  background-color: var(--color-bg-base);
  color: var(--color-text-primary);
  line-height: 1.5;
}

/* ========================================
   动画定义
   ======================================== */
@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes fade-out {
  from { opacity: 1; }
  to { opacity: 0; }
}

@keyframes slide-up {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes scale-in {
  from {
    opacity: 0;
    transform: scale(0.95);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

/* ========================================
   自定义 Utilities (@utility)
   ======================================== */
/* 常用的布局工具 */
@utility center-flex {
  display: flex;
  align-items: center;
  justify-content: center;
}

/* 玻璃态效果 */
@utility glass {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

/* 渐变背景 */
@utility gradient-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

/* 网格背景 */
@utility bg-grid {
  background-image: 
    linear-gradient(to right, rgb(0 0 0 / 0.05) 1px, transparent 1px),
    linear-gradient(to bottom, rgb(0 0 0 / 0.05) 1px, transparent 1px);
  background-size: 20px 20px;
}

/* ========================================
   滚动条样式
   ======================================== */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: light-dark(#f1f5f9, #1e293b);
}

::-webkit-scrollbar-thumb {
  background: light-dark(#cbd5e1, #475569);
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: light-dark(#94a3b8, #64748b);
}

/* ========================================
   第三方库样式（必要时保留）
   ======================================== */
.Vue-Toastification__container {
  z-index: 99999999 !important;
  pointer-events: none;
}

.Vue-Toastification__toast {
  pointer-events: auto;
}

/* ========================================
   无障碍优化
   ======================================== */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}

/* 焦点可见性 */
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

/* 高对比度模式 */
@media (prefers-contrast: high) {
  body {
    border: 2px solid currentColor;
  }
}
```

---

## 🚀 性能优势

使用 Tailwind CSS 4 推荐的方式：

1. **构建速度提升 30-50%** - 移除 `@apply` 处理
2. **CSS 体积减少** - 更好的 tree-shaking
3. **运行时性能提升** - 直接使用 CSS 变量
4. **开发体验改善** - 更快的 HMR

---

## 📚 参考资源

- [Tailwind CSS 4 官方文档](https://tailwindcss.com/docs)
- [Tailwind CSS 4 升级指南](https://tailwindcss.com/docs/upgrade-guide)
- [CSS light-dark() 函数](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/light-dark)
- [CSS @theme 规范](https://www.w3.org/TR/css-variables-2/)

---

**💡 记住：** Tailwind CSS 4 的核心理念是 **"Utility-First + Design Tokens"**，避免创建自定义抽象层！
