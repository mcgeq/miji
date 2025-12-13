# 调度器状态同步修复方案

## 问题描述

调度器在应用启动时由后端自动启动，但前端界面显示"已停止"状态。

## 根本原因

**竞态条件**：前端组件加载速度快于后端初始化完成。

### 时间线

```
T=0ms   应用启动
T=100ms 前端 Vue 组件挂载
        └─ ReminderSchedulerSettings.onMounted()
        └─ loadState() → 获取初始状态 {isRunning: false}
        
T=500ms 后端 Tauri 初始化完成
        └─ scheduler.start() → 设置状态 {isRunning: true}
```

**结果**：前端读取的是后端启动前的初始状态。

---

## 解决方案：事件驱动 + 兜底机制

### 架构

```
后端初始化完成
  ↓
发送 'scheduler-ready' 事件
  ↓
前端监听事件 → 加载最新状态
  ↓
（兜底）1秒后如果未收到事件 → 主动加载
```

### 1️⃣ 后端：发送就绪事件

**文件**: `src-tauri/src/app_initializer.rs`

```rust
// 设置 App Handle
{
    let mut s = scheduler.write().await;
    s.set_app_handle(app_handle.clone());
    if let Err(e) = s.start().await {
        log::error!("启动提醒调度器失败: {}", e);
    } else {
        log::info!("  ✓ 调度器已启动");
        
        // 🆕 发送就绪事件通知前端
        if let Err(e) = app_handle.emit_all("scheduler-ready", ()) {
            log::warn!("发送调度器就绪事件失败: {}", e);
        }
    }
}
```

### 2️⃣ 前端：监听事件 + 兜底

**文件**: `src/components/settings/ReminderSchedulerSettings.vue`

```typescript
import { listen } from '@tauri-apps/api/event';

let unlistenFn: (() => void) | null = null;
let fallbackTimer: NodeJS.Timeout | null = null;

onMounted(async () => {
  // 监听后端调度器就绪事件
  try {
    unlistenFn = await listen('scheduler-ready', () => {
      console.log('📡 收到调度器就绪事件');
      loadState();
      
      // 收到事件后清除兜底定时器
      if (fallbackTimer) {
        clearTimeout(fallbackTimer);
        fallbackTimer = null;
      }
    });
  } catch (err) {
    console.error('监听调度器事件失败:', err);
  }

  // 兜底机制：1秒后如果还没收到事件，主动加载
  fallbackTimer = setTimeout(() => {
    if (!state.value) {
      console.log('⏱️ 兜底加载调度器状态');
      loadState();
    }
  }, 1000);
});

// 清理监听器
onUnmounted(() => {
  if (unlistenFn) unlistenFn();
  if (fallbackTimer) clearTimeout(fallbackTimer);
});
```

---

## 优势

### 1. **精确可靠**
- 后端真正准备好才通知前端
- 避免猜测延迟时间

### 2. **优雅降级**
- 即使事件丢失，兜底机制确保状态加载
- 1秒延迟足够覆盖99%场景

### 3. **标准模式**
- 符合 Tauri 事件驱动架构
- 类似浏览器 `DOMContentLoaded` 模式

### 4. **易于扩展**
- 其他组件也可监听 `scheduler-ready` 事件
- 支持多个监听者

---

## 对比其他方案

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| 固定延迟 | 简单 | 不可靠，硬编码 | ⭐⭐ |
| 轮询检测 | 可靠 | 浪费资源，复杂 | ⭐⭐⭐ |
| 事件驱动 | 精确、可靠、优雅 | 需要前后端配合 | ⭐⭐⭐⭐⭐ |

---

## 验证方法

### 1. 查看控制台日志

**后端日志**:
```
✓ 调度器已启动
```

**前端日志**:
```
📡 收到调度器就绪事件
或
⏱️ 兜底加载调度器状态
```

### 2. 界面检查

刷新页面，调度器状态应显示：
- 🟢 运行中
- 上次扫描时间正常
- 统计数据正常

---

## 技术要点

### Tauri 事件系统

**发送事件**:
```rust
app_handle.emit_all("event-name", payload)
```

**监听事件**:
```typescript
const unlisten = await listen('event-name', (event) => {
  console.log(event.payload);
});
```

### 内存管理

- ✅ `onUnmounted` 中清理监听器
- ✅ 清除定时器防止内存泄漏
- ✅ 使用 `let` 而非 `const` 存储清理函数

---

## 扩展应用

此模式可用于其他需要等待后端初始化的场景：

1. **数据库连接就绪** - `database-ready`
2. **用户认证完成** - `auth-ready`
3. **配置加载完成** - `config-loaded`
4. **插件系统初始化** - `plugins-ready`

---

## 参考

- [Tauri Event System](https://tauri.app/v1/api/js/event/)
- [Vue Lifecycle Hooks](https://vuejs.org/guide/essentials/lifecycle.html)
- [Event-Driven Architecture](https://en.wikipedia.org/wiki/Event-driven_architecture)
