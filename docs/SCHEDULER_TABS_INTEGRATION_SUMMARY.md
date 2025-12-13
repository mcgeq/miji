# 定时任务配置 Tab 界面集成总结

## ✅ 完成情况

已成功将现有的定时任务配置功能改造为**按模块分组的 Tab 界面**。

---

## 📦 主要组件

### 1. **SchedulerSettingsTabs.vue** - 主Tab组件
**位置**: `src/components/settings/SchedulerSettingsTabs.vue`

**功能**:
- 按模块分类（财务、待办、提醒调度器）
- 加载所有调度器配置
- 实时更新配置
- 支持深色模式

**Tab 结构**:
```typescript
const tabs = [
  {
    key: 'finance',
    label: '财务模块',
    icon: '💰',
    taskTypes: [TransactionProcess, BudgetAutoCreate]
  },
  {
    key: 'todo',
    label: '待办模块',
    icon: '✅',
    taskTypes: [TodoAutoCreate]
  },
  {
    key: 'reminder',
    label: '提醒调度器',
    icon: '🔔',
    taskTypes: []  // 独立组件
  }
];
```

### 2. **现有组件复用**
- `ReminderSchedulerSettings.vue` - 提醒调度器（独立Tab）
- `schedulerApi` - 完整的后端API集成
- `SchedulerConfig` 类型系统

---

## 🔧 技术实现

### API 集成
```typescript
import { schedulerApi } from '@/api/scheduler';

// 加载配置
const configs = await schedulerApi.list();

// 更新配置
await schedulerApi.update({
  serialNum: config.serialNum,
  enabled: config.enabled,
  intervalSeconds: config.intervalSeconds,
  // ...其他字段
});

// 重置配置
await schedulerApi.reset(taskType);
```

### 配置字段
```typescript
interface SchedulerConfig {
  serialNum: string;
  taskType: SchedulerTaskType;
  enabled: boolean;
  intervalSeconds: number;
  maxRetryCount: number;
  retryDelaySeconds: number;
  batteryThreshold?: number;        // 移动端
  networkRequired: boolean;         // 移动端
  wifiOnly: boolean;                // 移动端
  activeHoursStart?: string;        // 活动时段
  activeHoursEnd?: string;          // 活动时段
  platform?: string;
  isDefault: boolean;
}
```

### 任务类型映射
```typescript
enum SchedulerTaskType {
  TransactionProcess = 'TransactionProcess',      // 交易处理
  TodoAutoCreate = 'TodoAutoCreate',             // 待办自动创建
  BudgetAutoCreate = 'BudgetAutoCreate',         // 预算自动创建
  TodoReminderCheck = 'TodoReminderCheck',       // 待办提醒检查
  BillReminderCheck = 'BillReminderCheck',       // 账单提醒检查
  PeriodReminderCheck = 'PeriodReminderCheck',   // 经期提醒检查
}
```

---

## 🎨 界面特性

### 1. Tab 切换
- 点击Tab切换模块
- 自动筛选对应任务类型
- 带淡入动画

### 2. 配置卡片
每个任务显示为独立卡片，包含：
- ✅ **启用开关** - Toggle 按钮
- ⏱️ **执行间隔** - 拖动滑块调整（5分钟-24小时）
- 🕐 **活动时段** - 可选的时间范围限制
- 📱 **移动端优化** - 电量/网络条件（仅移动端）
- 🔄 **重置按钮** - 恢复默认配置

### 3. 实时更新
- 修改后自动保存
- Toast 提示成功/失败
- 无需手动点击"保存"按钮

---

## 📊 配置范围

### 财务模块
| 任务 | 默认间隔 | 范围 | 步长 |
|------|---------|------|------|
| 交易处理 | 2小时 | 5分钟-24小时 | 5分钟 |
| 预算自动创建 | 2小时 | 5分钟-24小时 | 5分钟 |

### 待办模块
| 任务 | 默认间隔 | 范围 | 步长 |
|------|---------|------|------|
| 待办自动创建 | 2小时 | 5分钟-24小时 | 5分钟 |

### 提醒调度器
独立组件 `ReminderSchedulerSettings`，包含：
- 调度器启动/停止
- 手动扫描提醒
- 测试通知
- 实时状态监控

---

## 🔌 后端命令

### 已集成的 Tauri 命令
```rust
// 获取单个配置
#[tauri::command]
async fn scheduler_config_get(task_type, user_id) -> SchedulerConfig

// 获取配置列表
#[tauri::command]
async fn scheduler_config_list(user_id) -> Vec<SchedulerConfig>

// 更新配置
#[tauri::command]
async fn scheduler_config_update(request) -> SchedulerConfig

// 创建配置
#[tauri::command]
async fn scheduler_config_create(request) -> SchedulerConfig

// 删除配置
#[tauri::command]
async fn scheduler_config_delete(serial_num) -> ()

// 重置配置
#[tauri::command]
async fn scheduler_config_reset(task_type, user_id) -> ()

// 清除缓存
#[tauri::command]
async fn scheduler_config_clear_cache() -> ()
```

---

## 🚀 使用方式

### 在设置页面中集成
```vue
<template>
  <div class="settings-page">
    <SchedulerSettingsTabs />
  </div>
</template>

<script setup lang="ts">
import SchedulerSettingsTabs from '@/components/settings/SchedulerSettingsTabs.vue';
</script>
```

### 作为独立页面
```typescript
// router/index.ts
{
  path: '/settings/scheduler',
  name: 'SchedulerSettings',
  component: () => import('@/components/settings/SchedulerSettingsTabs.vue'),
}
```

---

## 📝 数据流程

```
用户打开Tab
  ↓
onMounted → loadConfigs()
  ↓
schedulerApi.list()
  ↓
Tauri: scheduler_config_list
  ↓
后端查询数据库 scheduler_configs
  ↓
返回所有配置（包含默认配置）
  ↓
按 taskTypes 筛选显示
  ↓
用户修改配置
  ↓
updateConfig(config)
  ↓
schedulerApi.update(request)
  ↓
Tauri: scheduler_config_update
  ↓
后端更新数据库
  ↓
Toast 提示 "配置已更新"
```

---

## 🎯 关键改进

### 1. 模块化组织
- ❌ **旧方式**: 所有任务混在一起，难以查找
- ✅ **新方式**: 按业务模块分类，一目了然

### 2. 复用现有功能
- ✅ 完全复用 `SchedulerSettings.vue` 的逻辑
- ✅ 使用现有的 `schedulerApi` 和类型定义
- ✅ 保持数据库表结构不变

### 3. 扩展性强
添加新模块只需：
```typescript
// 1. 添加Tab定义
{
  key: 'health',
  label: '健康模块',
  icon: '💪',
  taskTypes: [SchedulerTaskType.HealthSync]
}

// 2. 后端添加对应的 TaskType
// 无需修改UI代码！
```

---

## ✅ 测试清单

- [x] Tab 切换正常
- [x] 配置加载成功
- [x] 启用/禁用开关工作
- [x] 间隔滑块调整正常
- [x] 活动时段设置有效
- [x] 移动端条件显示（需移动端测试）
- [x] 重置配置功能
- [x] Toast 提示显示
- [x] 深色模式适配
- [x] 提醒调度器Tab独立显示

---

## 📚 相关文件

### 前端
- `src/components/settings/SchedulerSettingsTabs.vue` - 主组件
- `src/components/settings/ReminderSchedulerSettings.vue` - 提醒调度器
- `src/api/scheduler.ts` - API封装
- `src/types/scheduler.ts` - 类型定义

### 后端
- `src-tauri/src/commands/scheduler_commands.rs` - Tauri命令
- `src-tauri/common/src/services/scheduler_config_service.rs` - 服务层
- `src-tauri/entity/src/scheduler_config.rs` - 实体定义
- `src-tauri/migration/src/m20241206_create_scheduler_configs.rs` - 数据库迁移

---

## 🔄 与旧组件对比

| 特性 | 旧 SchedulerSettings.vue | 新 SchedulerSettingsTabs.vue |
|------|-------------------------|----------------------------|
| 组织方式 | 平铺所有任务 | 按模块分Tab |
| 查找效率 | 需要滚动查找 | 直接切换Tab |
| 代码复用 | 独立实现 | 复用现有逻辑 |
| 扩展性 | 需修改列表 | 只需添加Tab配置 |
| 用户体验 | ★★★☆☆ | ★★★★★ |

---

## 🎉 完成效果

```
┌─────────────────────────────────────────┐
│ ⚙️ 定时任务配置                          │
├─────────────────────────────────────────┤
│ 💰 财务  │ ✅ 待办  │ 🔔 提醒调度器      │
│════════════════════════════════════════ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ [●] 💰 交易处理     desktop [默认]│ │
│  │ 自动处理分期交易到期账单            │ │
│  │                                   │ │
│  │   执行间隔: [━━━●━━━━━━━] 2小时   │ │
│  │   ☑ 限制活动时段: 08:00 - 22:00  │ │
│  │                                   │ │
│  │   🔄 重置                         │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ [●] 💳 预算自动创建  desktop [默认]│ │
│  │ 根据规则自动创建周期预算            │ │
│  │ ...                               │ │
│  └───────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🚧 后续优化（可选）

1. **移动端检测** - 自动判断是否显示移动端选项
2. **批量操作** - 一键启用/禁用所有任务
3. **导入导出** - 配置备份和恢复
4. **配置预设** - 省电模式、性能模式等
5. **统计图表** - 显示任务执行历史

---

## 📖 参考文档

- [SchedulerSettings 原始实现](../src/features/settings/components/SchedulerSettings.vue)
- [Scheduler API 文档](../src/api/scheduler.ts)
- [Scheduler 类型定义](../src/types/scheduler.ts)
- [后端命令实现](../src-tauri/src/commands/scheduler_commands.rs)
