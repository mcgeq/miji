# 导航子菜单功能实现

## 🎯 功能概述

将MoneyView和家庭记账本合并为一个导航项，默认显示MoneyView，点击时展开子菜单导航。支持桌面端侧边栏和移动端底部导航。

## 📋 实现内容

### 1. **菜单结构重构**

#### 修改前
```typescript
const menuItems = [
  { name: 'money', title: 'Money', icon: HandCoins, path: '/money' },
  { name: 'family-ledger', title: 'Family Ledger', icon: Users, path: '/family-ledger' },
  // ...其他菜单项
];
```

#### 修改后
```typescript
const menuItems = [
  { 
    name: 'money', 
    title: 'Money', 
    icon: HandCoins, 
    path: '/money',
    hasSubmenu: true,
    submenu: [
      { name: 'money-overview', title: '账本概览', path: '/money' },
      { name: 'family-ledger', title: '家庭记账', path: '/family-ledger' },
    ]
  },
  // ...其他菜单项
];
```

### 2. **桌面端侧边栏 (Sidebar.vue)**

#### 功能特性
- **悬浮子菜单**: 点击带子菜单的项目时，在右侧显示悬浮子菜单
- **动态宽度**: 当有子菜单展开时，侧边栏保持紧凑设计
- **状态管理**: 自动展开包含当前路由的菜单项
- **平滑动画**: 子菜单展开/收起带有滑入动画

#### 核心实现
```typescript
// 展开状态管理
const expandedMenus = ref<Set<string>>(new Set());

// 导航逻辑
function navigate(item: MenuItem) {
  if (item.hasSubmenu) {
    // 切换子菜单展开状态
    if (expandedMenus.value.has(item.name)) {
      expandedMenus.value.delete(item.name);
    } else {
      expandedMenus.value.add(item.name);
    }
  } else if (item.path) {
    router.push(item.path);
  }
}

// 激活状态检测
function isActive(item: MenuItem) {
  if (item.hasSubmenu && item.submenu) {
    return item.submenu.some(sub => sub.path === route.path);
  }
  return item.path === route.path;
}
```

#### 样式特点
```css
/* 子菜单悬浮显示 */
.submenu {
  position: absolute;
  left: 100%;
  top: 0;
  background-color: var(--color-base-200);
  border-radius: 0.5rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  min-width: 8rem;
  z-index: 1001;
  animation: slideIn 0.2s ease-out;
}

/* 展开指示器 */
.chevron {
  width: 1rem;
  height: 1rem;
  transition: transform 0.3s ease;
}

.chevron.expanded {
  transform: rotate(180deg);
}
```

### 3. **移动端底部导航 (MobileBottomNav.vue)**

#### 功能特性
- **弹窗子菜单**: 点击带子菜单的项目时，从底部弹出子菜单
- **背景遮罩**: 显示半透明遮罩，点击可关闭子菜单
- **触摸友好**: 大按钮设计，适合移动端操作
- **自动关闭**: 选择子菜单项后自动关闭弹窗

#### 核心实现
```typescript
// 子菜单显示状态
const showSubmenu = ref<string | null>(null);

// 导航逻辑
function navigate(item: MenuItem) {
  if (item.hasSubmenu) {
    showSubmenu.value = showSubmenu.value === item.name ? null : item.name;
  } else if (item.path) {
    router.push(item.path);
    showSubmenu.value = null;
  }
}

// 子菜单导航
function navigateSubmenu(submenuItem: { name: string; title: string; path: string }) {
  router.push(submenuItem.path);
  showSubmenu.value = null; // 导航后关闭子菜单
}
```

#### 样式特点
```css
/* 背景遮罩 */
.submenu-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.3);
  z-index: 1001;
}

/* 弹窗子菜单 */
.mobile-submenu {
  position: fixed;
  bottom: 4rem;
  left: 1rem;
  right: 1rem;
  background-color: var(--color-base-100);
  border-radius: 0.75rem;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  animation: slideUp 0.3s ease-out;
}
```

### 4. **TypeScript接口定义**

```typescript
interface MenuItem {
  name: string;
  title: string;
  icon: any;
  path: string;
  hasSubmenu?: boolean;
  submenu?: Array<{ name: string; title: string; path: string }>;
}
```

## 🎨 用户体验

### 桌面端体验
1. **默认状态**: 侧边栏显示Money图标
2. **悬停效果**: 鼠标悬停显示tooltip
3. **点击展开**: 点击Money图标，右侧弹出子菜单
4. **子菜单选择**: 点击"账本概览"或"家庭记账"进行导航
5. **状态保持**: 当前页面对应的菜单项保持激活状态

### 移动端体验
1. **默认状态**: 底部导航显示Money图标
2. **点击弹窗**: 点击Money图标，从底部弹出子菜单
3. **背景遮罩**: 显示半透明背景，可点击关闭
4. **选择导航**: 点击子菜单项进行导航并自动关闭弹窗
5. **触摸优化**: 大按钮设计，适合手指操作

## 🔧 技术实现

### 状态管理
- **桌面端**: 使用`Set<string>`管理展开的菜单项
- **移动端**: 使用`string | null`管理当前显示的子菜单

### 路由集成
- **激活检测**: 自动检测当前路由并高亮对应菜单项
- **父子关联**: 父菜单项在子路由激活时也显示为激活状态
- **自动展开**: 页面加载时自动展开包含当前路由的菜单

### 动画效果
- **桌面端**: 子菜单滑入动画 + 箭头旋转动画
- **移动端**: 弹窗上滑动画 + 背景渐变动画

## 📱 响应式设计

### 断点处理
```typescript
const isMobile = ref(window.innerWidth < 768);

function updateIsMobile() {
  isMobile.value = window.innerWidth < 768;
}
```

### 组件切换
```vue
<template>
  <div class="layout">
    <!-- 桌面端侧边栏 -->
    <Sidebar v-if="!isMobile" :menu="menuItems" @logout="logout" />
    
    <!-- 移动端底部导航 -->
    <MobileBottomNav v-if="isMobile" :menu="menuItems" />
  </div>
</template>
```

## 🎯 优势特点

1. **空间节省**: 减少导航栏项目数量，保持界面简洁
2. **逻辑清晰**: 相关功能归类到同一菜单下
3. **用户友好**: 默认显示主要功能，次要功能通过子菜单访问
4. **响应式**: 桌面端和移动端采用不同但一致的交互方式
5. **可扩展**: 易于添加更多子菜单项或创建新的子菜单组

## 🚀 使用方法

### 添加新的子菜单项
```typescript
{
  name: 'money',
  title: 'Money',
  icon: HandCoins,
  path: '/money',
  hasSubmenu: true,
  submenu: [
    { name: 'money-overview', title: '账本概览', path: '/money' },
    { name: 'family-ledger', title: '家庭记账', path: '/family-ledger' },
    { name: 'new-feature', title: '新功能', path: '/money/new-feature' }, // 新增
  ]
}
```

### 创建新的子菜单组
```typescript
{
  name: 'reports',
  title: 'Reports',
  icon: BarChart3,
  path: '/reports',
  hasSubmenu: true,
  submenu: [
    { name: 'financial-report', title: '财务报表', path: '/reports/financial' },
    { name: 'analysis-report', title: '分析报表', path: '/reports/analysis' },
  ]
}
```

现在用户可以享受更简洁的导航体验，Money功能作为主入口，家庭记账作为子功能通过子菜单访问！
