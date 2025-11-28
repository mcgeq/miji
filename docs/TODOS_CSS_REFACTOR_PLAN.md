# Todos 模块 CSS 重构计划

## 📋 重构目标

将 `features/todos` 模块的所有自定义 CSS 重构为 Tailwind CSS 4，提取通用样式，提升代码可维护性。

---

## 📊 现状分析

### CSS 文件
| 文件 | 行数 | 说明 |
|------|------|------|
| `assets/styles/components/todo-buttons.css` | 194 行 | Todo按钮通用样式 |

### 组件 CSS统计
| 组件 | 总行数 | CSS行数 | 复杂度 |
|------|--------|---------|--------|
| TodoView.vue | 387 | 203 | 中 |
| TodoList.vue | 62 | 24 | 低 |
| TodoInput.vue | 299 | 184 | 中 |
| TodoItem.vue | 599 | 256 | 高 |
| 其他子组件 | ~15个 | 待分析 | - |

**总计**: ~667 行 CSS 需要重构

---

## 🎯 通用样式提取

### 1. Todo 按钮样式 (todo-buttons.css)

#### 基础样式
```css
.todo-btn {
  display: flex;
  align-items: center;
  gap: 0.375rem;  /* gap-1.5 */
  padding: 0.25rem 0.5rem;  /* px-2 py-1 */
  border: 1px solid;  /* border */
  border-radius: 0.5rem;  /* rounded-lg */
  transition: all 0.2s ease;  /* transition-all duration-200 */
  font-size: 0.75rem;  /* text-xs */
}
```

#### Tailwind 等效类
```vue
<button class="flex items-center gap-1.5 px-2 py-1 border rounded-lg 
               bg-base-100 text-base-content border-base-300
               hover:bg-base-200 hover:border-primary
               focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2
               transition-all duration-200 text-xs cursor-pointer outline-none">
</button>
```

#### 变体样式映射

| CSS类 | Tailwind等效 | 说明 |
|-------|-------------|------|
| `todo-btn--small` | `px-1.5 py-0.5 text-[10px] gap-1` | 小尺寸 |
| `todo-btn--large` | `px-3 py-1.5 text-sm gap-2` | 大尺寸 |
| `todo-btn--icon-only` | `p-1 justify-center` | 仅图标 |
| `todo-btn--primary` | `bg-primary text-primary-content border-primary` | 主要按钮 |
| `todo-btn--success` | `bg-success text-success-content border-success` | 成功 |
| `todo-btn--warning` | `bg-warning text-warning-content border-warning` | 警告 |
| `todo-btn--error` | `bg-error text-error-content border-error` | 错误 |
| `todo-btn--active` | `bg-base-200 border-base-content font-semibold` | 激活状态 |
| `todo-btn--readonly` | `cursor-default opacity-60` | 只读 |
| `:disabled` | `cursor-not-allowed opacity-50` | 禁用 |

### 2. 优先级样式 (TodoItem.vue)

#### CSS渐变背景
```css
.priority-low {
  background: linear-gradient(135deg, base-100 0%, success-tint 100%);
  border-color: success-fade;
}
```

#### Tailwind方案
使用 `@layer components` 定义复用类：
```css
@layer components {
  .priority-gradient-low {
    @apply bg-gradient-to-br from-base-100 to-success/5 border-success/20;
  }
  .priority-gradient-medium {
    @apply bg-gradient-to-br from-base-100 to-warning/5 border-warning/20;
  }
  .priority-gradient-high {
    @apply bg-gradient-to-br from-base-100 to-error/5 border-error/20;
  }
  .priority-gradient-urgent {
    @apply bg-gradient-to-br from-base-100 to-error/10 border-error 
           shadow-md shadow-error/30;
  }
}
```

### 3. 动画

#### CSS关键帧
```css
@keyframes urgent-pulse {
  0%, 100% { box-shadow: 0 0 16px var(--color-error); }
  50% { box-shadow: 0 0 24px var(--color-error); }
}
```

#### Tailwind配置
```js
// tailwind.config.js
theme: {
  extend: {
    keyframes: {
      'urgent-pulse': {
        '0%, 100%': { boxShadow: '0 0 16px var(--color-error)' },
        '50%': { boxShadow: '0 0 24px var(--color-error)' }
      }
    },
    animation: {
      'urgent-pulse': 'urgent-pulse 2s ease-in-out infinite'
    }
  }
}
```

---

## 📝 重构顺序

### Phase 1: 简单组件 ✅
1. ✅ **TodoList.vue** (24行CSS) - 简单布局
2. **TodoView.vue** (203行CSS) - 页面容器

### Phase 2: 输入组件
3. **TodoInput.vue** (184行CSS) - 输入框和按钮

### Phase 3: 核心组件
4. **TodoItem.vue** (256行CSS) - 最复杂组件
   - 优先级渐变背景
   - 交互状态
   - 响应式布局

### Phase 4: 子组件 (~15个)
5. **TodoCheckbox.vue**
6. **TodoTitle.vue**
7. **TodoActions.vue**
8. **TodoProgress.vue**
9. **TodoEstimate.vue**
10. **TodoLocation.vue**
11. **TodoReminderSettings.vue**
12. **TodoSubtasks.vue**
13. **TodoSmartFeatures.vue**
14. **TodoAddMenus.vue**
15. **TodoEditOptionsModal.vue**
16. **TodoEditTitleModal.vue**
17. **TodoEditDueDateModal.vue**
18. **TodoEditRepeatModal.vue**

### Phase 5: 清理
19. ❌ **删除** `todo-buttons.css`
20. ✅ **更新** `assets/styles/index.css`

---

## 🎨 Tailwind 扩展配置

### 自定义组件类
```css
/* src/assets/styles/components/todos.css (新建) */
@layer components {
  /* Todo按钮基础 */
  .todo-btn-base {
    @apply flex items-center gap-1.5 px-2 py-1 
           border rounded-lg text-xs
           bg-base-100 text-base-content border-base-300
           hover:bg-base-200 hover:border-primary
           focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2
           transition-all duration-200 cursor-pointer outline-none;
  }
  
  /* 优先级渐变 */
  .priority-gradient-low {
    @apply bg-gradient-to-br from-base-100 to-success/5 border-success/20;
  }
  
  .priority-gradient-medium {
    @apply bg-gradient-to-br from-base-100 to-warning/5 border-warning/20;
  }
  
  .priority-gradient-high {
    @apply bg-gradient-to-br from-base-100 to-error/5 border-error/20;
  }
  
  .priority-gradient-urgent {
    @apply bg-gradient-to-br from-base-100 to-error/10 border-error 
           shadow-md shadow-error/30;
  }
  
  /* Todo卡片 */
  .todo-card {
    @apply mb-1 p-4 lg:p-6 rounded-2xl border border-base-300
           bg-base-100 shadow-sm backdrop-blur-sm
           hover:shadow-lg hover:border-primary hover:-translate-y-0.5
           transition-all duration-300;
  }
}
```

---

## ✅ 重构检查清单

### 组件级别
- [ ] 删除 `<style scoped>` 中的所有 CSS
- [ ] 使用 Tailwind 类替换样式
- [ ] 保持功能完全一致
- [ ] 测试响应式布局
- [ ] 测试暗色模式
- [ ] 测试交互状态

### 通用样式
- [ ] 提取复用类到 `@layer components`
- [ ] 配置 Tailwind 主题扩展
- [ ] 确保颜色使用 CSS 变量

### 清理
- [ ] 删除 `todo-buttons.css`
- [ ] 更新 CSS 入口文件

---

## 📈 预期成果

### 代码质量
- ✅ **删除 ~850+ 行自定义 CSS**
- ✅ **100% Tailwind CSS 4**
- ✅ **提取 ~10 个通用组件类**
- ✅ **响应式完美适配**
- ✅ **暗色模式支持**

### 性能
- ✅ **减少 CSS 体积**
- ✅ **更好的 Tree-shaking**
- ✅ **统一设计语言**

---

## 🚀 开始重构

**当前进度**: 0% (0/19)

**下一步**: 重构 TodoView.vue
