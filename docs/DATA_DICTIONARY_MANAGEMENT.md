# 数据字典管理界面实现文档

## 概述

实现了统一的数据字典管理界面，集成了 Categories（分类）、SubCategories（子分类）、Projects（项目）、Tags（标签）四个核心数据实体的管理功能。

**路由整合**: 原有的 `/tags` 和 `/projects` 路由已重定向到 `/dictionaries`，侧边栏和移动端底部导航只保留一个统一入口。

## 实现内容

### 1. 新增组件

#### 1.1 分类管理组件
- **CategoryItem.vue** - 分类卡片组件
  - 路径: `src/features/money/components/CategoryItem.vue`
  - 功能: 显示和编辑单个分类（名称、图标）
  - 特性: 只读模式、删除按钮

- **CategoriesView.vue** - 分类列表视图
  - 路径: `src/features/money/views/CategoriesView.vue`
  - 功能: 展示所有分类，支持刷新
  - 特性: 网格布局、加载状态、错误提示

#### 1.2 子分类管理组件
- **SubCategoryItem.vue** - 子分类卡片组件
  - 路径: `src/features/money/components/SubCategoryItem.vue`
  - 功能: 显示和编辑单个子分类（名称、图标）
  - 特性: 只读模式、删除按钮、紧凑布局

- **SubCategoriesView.vue** - 子分类列表视图
  - 路径: `src/features/money/views/SubCategoriesView.vue`
  - 功能: 按父分类分组展示子分类
  - 特性: 折叠/展开、全部展开/折叠、刷新

#### 1.3 统一管理页面
- **dictionaries.vue** - 数据字典管理页面
  - 路径: `src/pages/dictionaries.vue`
  - 功能: Tab 式导航，集成所有数据字典管理功能
  - Tab 列表:
    - 分类 (Categories)
    - 子分类 (SubCategories)
    - 项目 (Projects) - 复用现有组件
    - 标签 (Tags) - 复用现有组件

### 2. 路由整合

#### 2.1 主路由
**dictionaries.vue** (`src/pages/dictionaries.vue`)
- 路径: `/dictionaries`
- 包含完整的 Tab 导航和四个模块

#### 2.2 重定向路由
为保持向后兼容，原有路由重定向到统一入口：

**tags.vue** (`src/pages/tags.vue`)
- 原路径: `/tags`
- 重定向到: `/dictionaries`

**projects.vue** (`src/pages/projects.vue`)
- 原路径: `/projects`
- 重定向到: `/dictionaries`

#### 2.3 导航菜单更新
修改了 `src/layouts/DefaultLayout.vue`：
- ✅ 添加: `{ name: 'dictionaries', title: 'Dictionaries', icon: BookOpen, path: '/dictionaries' }`
- ❌ 移除: `{ name: 'tags', ... }`
- ❌ 移除: `{ name: 'projects', ... }`

**结果**: 侧边栏和移动端底部导航只保留一个 "Dictionaries" 入口

## 功能特性

### 分类管理
- ✅ 查看所有分类（21 个预设分类）
- ✅ 网格布局展示
- ✅ 显示分类图标和名称
- ✅ 刷新数据
- 🔄 添加新分类（待后端 API）
- 🔄 编辑分类（待后端 API）
- 🔄 删除分类（待后端 API）

### 子分类管理
- ✅ 按父分类分组查看
- ✅ 折叠/展开每个分类组
- ✅ 全部展开/全部折叠
- ✅ 显示子分类图标和名称
- ✅ 刷新数据
- 🔄 添加新子分类（待后端 API）
- 🔄 编辑子分类（待后端 API）
- 🔄 删除子分类（待后端 API）

### 项目管理
- ✅ 复用现有 ProjectsView 组件
- ✅ 使用 GenericViewItem 通用组件
- ✅ 显示使用统计

### 标签管理
- ✅ 复用现有 TagsView 组件
- ✅ 使用 GenericViewItem 通用组件
- ✅ 显示使用统计

## 技术实现

### 状态管理
使用现有的 `useCategoryStore`：
- 分类数据缓存（5分钟）
- 子分类数据缓存（5分钟）
- 加载状态管理
- 错误状态管理

### 数据获取
通过 `MoneyDb` 服务层调用后端 API：
- `MoneyDb.listCategory()` - 获取分类列表
- `MoneyDb.listSubCategory()` - 获取子分类列表

### 后端 API
已有的 Tauri 命令：
- `category_list` - 获取所有分类
- `sub_category_list` - 获取所有子分类
- `project_list` - 获取所有项目
- `tag_list` - 获取所有标签

## 界面设计

### 布局结构
```
┌─────────────────────────────────────────────────┐
│  数据字典管理                                      │
├─────────────────────────────────────────────────┤
│  [分类] [子分类] [项目] [标签]                      │
├─────────────────────────────────────────────────┤
│                                                 │
│  当前选中 Tab 的内容区域                           │
│                                                 │
│  分类: 网格布局，显示所有分类卡片                     │
│  子分类: 分组折叠布局，按父分类分组                   │
│  项目: GenericViewItem 通用组件                   │
│  标签: GenericViewItem 通用组件                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 响应式设计
- 分类: 2-6 列自适应网格
- 子分类: 2-8 列自适应网格
- 支持深色模式
- 移动端适配

## 待完善功能

### 后端 API 需求
以下功能需要后端提供相应的 API：

1. **分类管理**
   - `category_create` - 创建分类
   - `category_update` - 更新分类
   - `category_delete` - 删除分类

2. **子分类管理**
   - `sub_category_create` - 创建子分类
   - `sub_category_update` - 更新子分类
   - `sub_category_delete` - 删除子分类

### 前端增强
1. 添加分类/子分类的模态框
2. 编辑功能的完整实现
3. 删除确认对话框
4. 表单验证（名称长度、图标格式等）
5. 错误处理和用户提示
6. 搜索和筛选功能
7. 批量操作功能

## 数据约束

根据现有的 Schema 定义：

### Category
- `name`: CategoryNameSchema (2-20 字符)
- `icon`: 字符串（通常是 emoji）
- `createdAt`: 时间戳
- `updatedAt`: 时间戳（可选）

### SubCategory
- `name`: SubCategoryNameSchema (2-20 字符)
- `categoryName`: CategoryNameSchema
- `icon`: 字符串（通常是 emoji）
- `createdAt`: 时间戳
- `updatedAt`: 时间戳（可选）

### 主键约束
- Categories: `name` (唯一)
- SubCategories: `(name, categoryName)` 复合主键
- Projects: `serialNum` (UUID)
- Tags: `serialNum` (UUID)

## 使用说明

### 访问路径
通过侧边栏导航菜单点击 "Dictionaries" 图标，或直接访问 `/dictionaries` 路径。

### 操作步骤

1. **查看分类**
   - 点击 "分类" Tab
   - 浏览所有分类
   - 点击"刷新"按钮更新数据

2. **查看子分类**
   - 点击 "子分类" Tab
   - 点击分类头部展开/折叠
   - 使用"全部展开"/"全部折叠"快速操作

3. **查看项目/标签**
   - 点击对应 Tab
   - 查看和管理项目/标签

## 文件清单

### 新增文件
```
src/features/money/components/
  ├── CategoryItem.vue
  └── SubCategoryItem.vue

src/features/money/views/
  ├── CategoriesView.vue
  └── SubCategoriesView.vue

src/pages/
  └── dictionaries.vue

docs/
  └── DATA_DICTIONARY_MANAGEMENT.md
```

### 修改文件
```
src/layouts/DefaultLayout.vue
  - 添加 dictionaries 菜单项
  - 移除 tags 和 projects 独立菜单项
  - 优化图标导入

src/pages/tags.vue
  - 改为重定向到 /dictionaries

src/pages/projects.vue
  - 改为重定向到 /dictionaries
```

## 性能考虑

1. **数据缓存**: 使用 Pinia Store 缓存数据，避免频繁 API 调用
2. **缓存时间**: 5分钟缓存过期时间
3. **懒加载**: 仅在访问对应 Tab 时加载数据
4. **折叠优化**: 子分类默认折叠，减少初始渲染压力

## 兼容性

- ✅ 深色模式支持
- ✅ 响应式布局
- ✅ 移动端适配
- ✅ 与现有系统集成

## 总结

本次实现成功将 Categories、SubCategories、Projects、Tags 四个核心数据实体的管理功能整合到统一的数据字典管理界面中，提供了：

- **统一的访问入口**: 通过单一页面 `/dictionaries` 管理所有数据字典
- **一致的用户体验**: 统一的设计风格和交互模式
- **简化的导航**: 侧边栏和移动端底部导航只保留一个入口，避免菜单臃肿
- **向后兼容**: 原有 `/tags` 和 `/projects` 路由自动重定向，不影响现有链接
- **可扩展的架构**: 易于添加新的数据实体管理
- **良好的代码复用**: 充分利用现有组件和服务

### 优势

1. **减少导航混乱**: 从 3 个独立入口整合为 1 个统一入口
2. **提升用户体验**: Tab 式导航更直观，相关功能集中管理
3. **便于维护**: 集中管理，修改更方便
4. **移动端友好**: 底部导航栏空间更充裕

待后端 API 完善后，即可实现完整的增删改查功能。
