# 定时任务配置 Tab 组件使用文档

## 📋 组件概览

按功能模块组织的定时任务配置界面，支持：
- 💰 **财务模块** - 交易处理 + 预算自动创建
- ✅ **待办模块** - 待办自动创建
- 🔔 **提醒调度器** - 统一提醒管理

---

## 🎨 组件结构

```
SchedulerSettingsTabs.vue          (主Tab组件)
  ├─ SchedulerTaskConfig.vue       (通用任务配置)
  │   ├─ 启用/禁用开关
  │   ├─ 执行间隔配置
  │   ├─ 活动时段限制
  │   └─ 移动端条件 (可选)
  └─ ReminderSchedulerSettings.vue (提醒调度器)
      ├─ 调度器状态
      ├─ 手动扫描
      └─ 测试通知
```

---

## 📦 安装使用

### 1. 在设置页面中引入

**文件：** `src/views/SettingsView.vue`

```vue
<template>
  <div class="settings-view">
    <!-- 其他设置 -->
    
    <!-- 定时任务配置 -->
    <SchedulerSettingsTabs />
  </div>
</template>

<script setup lang="ts">
import SchedulerSettingsTabs from '@/components/settings/SchedulerSettingsTabs.vue';
</script>
```

### 2. 作为独立页面

**文件：** `src/router/index.ts`

```typescript
{
  path: '/settings/scheduler',
  name: 'SchedulerSettings',
  component: () => import('@/components/settings/SchedulerSettingsTabs.vue'),
}
```

---

## ⚙️ 配置项说明

### SchedulerTaskConfig 配置

```typescript
interface SchedulerConfig {
  enabled: boolean;              // 是否启用
  interval: number;              // 执行间隔（秒）
  activeHours?: [string, string]; // 活动时段 ["09:00", "18:00"]
  
  // 移动端专用
  networkRequired?: boolean;     // 需要网络连接
  wifiOnly?: boolean;           // 仅Wi-Fi
  batteryThreshold?: number;    // 最低电量 (0-100)
}
```

### 任务类型配置

| 任务类型 | 图标 | 默认间隔 | 说明 |
|---------|------|---------|------|
| Transaction | 🔄 | 2小时 | 处理分期交易到期账单 |
| Todo | 📝 | 2小时 | 创建重复待办事项 |
| Budget | 💰 | 2小时 | 创建周期性预算 |

---

## 🎯 功能特性

### 1. Tab 切换
- 点击Tab切换不同模块
- 带动画过渡效果
- 记住上次选中的Tab

### 2. 实时配置
- 修改后立即显示保存提示
- 底部浮动保存按钮
- 重启应用后生效提示

### 3. 移动端适配
- 自动检测移动端环境
- 显示额外配置项（网络、电量）
- 响应式布局

### 4. 表单验证
- 间隔时间不能为0
- 活动时段开始时间 < 结束时间
- 电量阈值 0-100%

---

## 🔧 自定义扩展

### 添加新模块

**步骤 1:** 在 `SchedulerSettingsTabs.vue` 中添加Tab

```typescript
const tabs: Tab[] = [
  { key: 'finance', label: '财务模块', icon: '💰' },
  { key: 'todo', label: '待办模块', icon: '✅' },
  { key: 'health', label: '健康模块', icon: '💪' }, // 新增
  { key: 'reminder', label: '提醒调度器', icon: '🔔' },
];
```

**步骤 2:** 添加Tab内容

```vue
<!-- 健康模块 -->
<div v-show="activeTab === 'health'" class="tab-panel">
  <div class="panel-header">
    <h4>💪 健康模块定时任务</h4>
    <p>自动处理健康数据统计</p>
  </div>
  <SchedulerTaskConfig task-type="HealthSync" @update:config="saveConfig('HealthSync', $event)" />
</div>
```

**步骤 3:** 在 `SchedulerTaskConfig.vue` 中添加任务配置

```typescript
const taskConfigs: Record<string, TaskConfig> = {
  // ... 现有配置
  HealthSync: {
    type: 'HealthDataSync',
    icon: '💪',
    label: '健康数据同步',
    description: '自动同步和统计健康数据',
    defaultInterval: 3600, // 1小时
  },
};
```

### 自定义任务配置UI

如果某个任务需要特殊配置项，可以创建专用组件：

```vue
<!-- HealthTaskConfig.vue -->
<template>
  <div class="health-task-config">
    <SchedulerTaskConfig task-type="HealthSync">
      <!-- 插槽：额外配置 -->
      <template #extra-settings>
        <div class="sync-sources">
          <label>同步数据源</label>
          <checkbox-group v-model="syncSources">
            <checkbox value="steps">步数</checkbox>
            <checkbox value="sleep">睡眠</checkbox>
            <checkbox value="heart">心率</checkbox>
          </checkbox-group>
        </div>
      </template>
    </SchedulerTaskConfig>
  </div>
</template>
```

---

## 📊 数据流

```
用户修改配置
  ↓
SchedulerTaskConfig @update:config
  ↓
SchedulerSettingsTabs.saveConfig()
  ↓
pendingConfigs 缓存
  ↓
用户点击"保存配置"
  ↓
applyChanges() → 后端API
  ↓
Toast 提示 + 重置状态
```

---

## 🔌 后端集成

### 需要的API接口

```typescript
// src/api/schedulerConfig.ts

interface SchedulerConfigApi {
  // 获取所有任务配置
  getConfigs(): Promise<Record<string, SchedulerConfig>>;
  
  // 更新配置
  updateConfigs(configs: Record<string, SchedulerConfig>): Promise<void>;
  
  // 重启调度器
  restartScheduler(): Promise<void>;
}
```

### Tauri 命令

```rust
// src-tauri/src/commands/scheduler_config.rs

#[tauri::command]
pub async fn get_scheduler_configs(
    state: State<'_, AppState>,
) -> Result<HashMap<String, SchedulerConfig>, String> {
    // 从数据库读取配置
}

#[tauri::command]
pub async fn update_scheduler_configs(
    state: State<'_, AppState>,
    configs: HashMap<String, SchedulerConfig>,
) -> Result<(), String> {
    // 保存到数据库
    // 通知调度器重新加载配置
}
```

---

## 🎨 主题定制

```css
/* 自定义主题变量 */
:root {
  --scheduler-tab-active-color: #3b82f6;
  --scheduler-bg-elevated: #ffffff;
  --scheduler-border-color: #e5e7eb;
}

/* 暗色主题 */
.dark {
  --scheduler-tab-active-color: #60a5fa;
  --scheduler-bg-elevated: #1f2937;
  --scheduler-border-color: #374151;
}
```

---

## ✅ 测试清单

- [ ] Tab 切换正常，动画流畅
- [ ] 配置修改后显示保存提示
- [ ] 保存配置成功并显示 Toast
- [ ] 移动端显示额外配置项
- [ ] 间隔时间单位转换正确
- [ ] 活动时段选择正常
- [ ] 电量阈值拖动正常
- [ ] 响应式布局在不同屏幕正常

---

## 🐛 已知问题

1. **移动端检测** - 目前是硬编码 `isMobile = false`，需要实际检测环境
2. **配置持久化** - 保存到本地存储或后端（待实现）
3. **配置验证** - 需要添加更严格的表单验证

---

## 📚 相关文档

- [ReminderSchedulerSettings 文档](./REMINDER_SCHEDULER_SETTINGS.md)
- [定时任务后端实现](../src-tauri/crates/notification/README.md)
- [配置数据库表结构](./database/scheduler_configs.md)

---

## 🎉 完成效果

```
┌──────────────────────────────────────────┐
│ ⚙️ 定时任务配置                            │
│ 根据模块管理自动任务和提醒                   │
├──────────────────────────────────────────┤
│ 💰 财务模块 │ ✅ 待办模块 │ 🔔 提醒调度器   │
│════════════════════════════════════════  │
│                                          │
│  🔄 交易处理                              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  [开] 自动处理分期交易到期账单              │
│       执行间隔: [2] [小时 ▼]              │
│       ☑ 限制活动时段: 09:00 - 18:00       │
│                                          │
│  💰 预算自动创建                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  [关] 自动创建周期性预算                  │
│                                          │
└──────────────────────────────────────────┘
         ╭──────────────────────────╮
         │ ℹ️ 配置已修改  [保存配置]  │
         ╰──────────────────────────╯
```
