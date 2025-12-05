# 通知权限实现策略

**目标**: 在 Tauri 应用中实现移动端通知权限请求  
**状态**: 📋 策略规划  
**更新时间**: 2024-12-06

---

## 📋 问题分析

### 当前状况

我们已经创建了权限管理接口，但返回的是假设值：

```rust
// notification_setup.rs
pub async fn request_notification_permission(_app: &AppHandle) -> Result<bool, String> {
    log::warn!("⚠️ 权限请求功能待实现");
    Ok(true) // 暂时假设有权限
}
```

### 为什么需要实际实现？

1. **Android 13+ (API 33)**: 必须运行时请求 `POST_NOTIFICATIONS` 权限
2. **iOS 所有版本**: 必须请求 User Notifications 权限
3. **用户体验**: 需要检测权限状态，引导用户授权

---

## 🎯 实现方案对比

### 方案 1: 等待 Tauri 官方支持 ⏰

**优势**:
- ✅ 官方维护，稳定性高
- ✅ API 一致性好
- ✅ 社区支持完善

**劣势**:
- ❌ 当前版本不支持
- ❌ 等待时间不确定
- ❌ 无法立即使用

**适用场景**: 
- 不着急上线移动端
- 可以等待 6-12 个月

**评分**: 7/10

---

### 方案 2: 使用社区插件 🔌

**可用插件**:

#### A. tauri-plugin-permissions (社区)

```toml
[dependencies]
tauri-plugin-permissions = "0.1.0"
```

**优势**:
- ✅ 开箱即用
- ✅ 支持多种权限
- ✅ 维护较活跃

**劣势**:
- ❌ 非官方插件，稳定性待验证
- ❌ 可能与 Tauri 版本不兼容
- ❌ 功能可能不完整

**使用示例**:
```rust
use tauri_plugin_permissions::{PermissionsExt, Permission};

#[tauri::command]
async fn request_notification_permission(app: AppHandle) -> Result<bool, String> {
    let has_permission = app.permissions()
        .check(Permission::PostNotifications)
        .await
        .map_err(|e| e.to_string())?;
    
    if !has_permission {
        app.permissions()
            .request(Permission::PostNotifications)
            .await
            .map_err(|e| e.to_string())
    } else {
        Ok(true)
    }
}
```

**评分**: 6/10

---

### 方案 3: 创建自定义 Tauri 插件 🛠️ (推荐)

**架构**:
```
tauri-plugin-mobile-notification-permission/
├── Cargo.toml
├── src/
│   ├── lib.rs (Rust 接口)
│   └── commands.rs
├── android/
│   └── src/main/java/...
│       └── PermissionPlugin.kt
└── ios/
    └── Sources/
        └── PermissionPlugin.swift
```

**优势**:
- ✅ 完全可控
- ✅ 针对性强
- ✅ 可扩展其他权限
- ✅ 学习 Tauri 插件开发

**劣势**:
- ❌ 开发成本高 (3-5天)
- ❌ 需要维护
- ❌ 需要原生开发知识

**实现步骤**:

#### 1. 创建插件项目

```bash
cargo new --lib tauri-plugin-mobile-notification-permission
```

#### 2. Rust 接口 (src/lib.rs)

```rust
use tauri::{
    plugin::{Builder, TauriPlugin},
    Runtime, Manager, AppHandle,
};

#[cfg(target_os = "android")]
use tauri::plugin::PluginApi;

#[cfg(target_os = "ios")]
use tauri::plugin::PluginApi;

pub struct NotificationPermission<R: Runtime> {
    app: AppHandle<R>,
}

impl<R: Runtime> NotificationPermission<R> {
    pub fn new(app: AppHandle<R>) -> Self {
        Self { app }
    }

    #[cfg(target_os = "android")]
    pub async fn request_permission(&self) -> Result<bool, String> {
        // 调用 Android 原生代码
        self.app
            .plugin_api()
            .android()
            .call("requestNotificationPermission", ())
            .await
            .map_err(|e| e.to_string())
    }

    #[cfg(target_os = "ios")]
    pub async fn request_permission(&self) -> Result<bool, String> {
        // 调用 iOS 原生代码
        self.app
            .plugin_api()
            .ios()
            .call("requestNotificationPermission", ())
            .await
            .map_err(|e| e.to_string())
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    pub async fn request_permission(&self) -> Result<bool, String> {
        Ok(true) // 桌面端默认有权限
    }
}

#[tauri::command]
async fn request_permission<R: Runtime>(
    app: AppHandle<R>,
    permission: tauri::State<'_, NotificationPermission<R>>,
) -> Result<bool, String> {
    permission.request_permission().await
}

pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("mobile-notification-permission")
        .invoke_handler(tauri::generate_handler![request_permission])
        .setup(|app, _api| {
            app.manage(NotificationPermission::new(app.clone()));
            Ok(())
        })
        .build()
}
```

#### 3. Android 原生代码 (android/.../PermissionPlugin.kt)

```kotlin
package com.mcgeq.tauri.permission

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.gson.Gson
import app.tauri.annotation.Command
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import app.tauri.plugin.Invoke

@TauriPlugin
class PermissionPlugin(private val activity: Activity) : Plugin(activity) {
    
    companion object {
        private const val REQUEST_CODE_NOTIFICATION = 1001
    }
    
    private var pendingInvoke: Invoke? = null
    
    @Command
    fun requestNotificationPermission(invoke: Invoke) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // Android 12 及以下不需要运行时权限
            invoke.resolve(JSObject().put("granted", true))
            return
        }
        
        val permission = Manifest.permission.POST_NOTIFICATIONS
        
        when {
            ContextCompat.checkSelfPermission(
                activity,
                permission
            ) == PackageManager.PERMISSION_GRANTED -> {
                // 已有权限
                invoke.resolve(JSObject().put("granted", true))
            }
            else -> {
                // 请求权限
                pendingInvoke = invoke
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(permission),
                    REQUEST_CODE_NOTIFICATION
                )
            }
        }
    }
    
    @Command
    fun checkNotificationPermission(invoke: Invoke) {
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        invoke.resolve(JSObject().put("granted", granted))
    }
    
    // 处理权限请求结果
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQUEST_CODE_NOTIFICATION) {
            val granted = grantResults.isNotEmpty() && 
                         grantResults[0] == PackageManager.PERMISSION_GRANTED
            
            pendingInvoke?.resolve(JSObject().put("granted", granted))
            pendingInvoke = null
        }
    }
}
```

#### 4. iOS 原生代码 (ios/.../PermissionPlugin.swift)

```swift
import UIKit
import Tauri
import UserNotifications

class PermissionPlugin: Plugin {
    
    @objc func requestNotificationPermission(_ invoke: Invoke) {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    invoke.reject(error.localizedDescription)
                } else {
                    invoke.resolve(["granted": granted])
                }
            }
        }
    }
    
    @objc func checkNotificationPermission(_ invoke: Invoke) {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                let granted = settings.authorizationStatus == .authorized
                invoke.resolve(["granted": granted])
            }
        }
    }
}
```

#### 5. 集成到项目

```rust
// src-tauri/src/lib.rs
use tauri_plugin_mobile_notification_permission;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_mobile_notification_permission::init())
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

**评分**: 9/10 ⭐

---

### 方案 4: 通过 WebView Bridge 实现 🌐

**原理**: 在 WebView 中调用原生 API

**Android (通过 JavaScript Bridge)**:
```kotlin
// MainActivity.kt
webView.addJavascriptInterface(NotificationPermissionBridge(), "notificationBridge")

class NotificationPermissionBridge {
    @JavascriptInterface
    fun requestPermission(callback: String) {
        // 请求权限
        // 完成后调用回调
    }
}
```

**前端调用**:
```typescript
// 仅限 Android/iOS WebView
declare global {
  interface Window {
    notificationBridge?: {
      requestPermission: (callback: string) => void;
    };
  }
}

function requestPermission(): Promise<boolean> {
  return new Promise((resolve) => {
    if (window.notificationBridge) {
      const callback = `__callback_${Date.now()}`;
      (window as any)[callback] = (granted: boolean) => {
        resolve(granted);
        delete (window as any)[callback];
      };
      window.notificationBridge.requestPermission(callback);
    } else {
      resolve(false);
    }
  });
}
```

**优势**:
- ✅ 无需创建插件
- ✅ 实现较快

**劣势**:
- ❌ 架构不优雅
- ❌ 类型安全性差
- ❌ 难以维护

**评分**: 5/10

---

## 🎯 推荐方案

### 短期方案（1-2周内）: 方案 2 (社区插件)

**原因**:
- 快速实现基本功能
- 可以先在测试环境验证
- 后续可以替换

**实施步骤**:
1. 调研社区可用插件
2. 测试插件兼容性
3. 集成到项目
4. 真机测试

### 长期方案（1-2月后）: 方案 3 (自定义插件)

**原因**:
- 完全掌控
- 可扩展性强
- 学习价值高

**实施步骤**:
1. 学习 Tauri 插件开发
2. 实现 Android 部分
3. 实现 iOS 部分
4. 编写测试和文档
5. 替换社区插件

---

## 📋 实施计划

### Phase 3.1: 平台配置 (当前) ✅

- [x] 创建 Android 配置指南
- [x] 创建 iOS 配置指南
- [x] 创建权限策略文档

### Phase 3.2: 社区插件集成 (1-2天)

- [ ] 调研可用插件
- [ ] 选择最合适的插件
- [ ] 集成到项目
- [ ] 更新 Rust 代码
- [ ] 测试基本功能

### Phase 3.3: 真机测试 (2-3天)

- [ ] Android 真机测试
  - [ ] Android 13+ 权限请求
  - [ ] 通知渠道显示
  - [ ] 后台通知
  - [ ] Doze 模式测试

- [ ] iOS 真机测试
  - [ ] 权限请求对话框
  - [ ] 通知显示
  - [ ] Focus 模式测试
  - [ ] 后台通知

### Phase 3.4: 自定义插件开发 (1-2周，可选)

- [ ] 创建插件项目结构
- [ ] 实现 Rust 接口
- [ ] 实现 Android 原生代码
- [ ] 实现 iOS 原生代码
- [ ] 编写单元测试
- [ ] 编写集成测试
- [ ] 编写文档

---

## 📚 学习资源

### Tauri 插件开发
- [Tauri Plugin Guide](https://v2.tauri.app/plugin/)
- [Tauri Plugin Template](https://github.com/tauri-apps/tauri-plugin-template)
- [Official Plugins Source](https://github.com/tauri-apps/plugins-workspace)

### Android 开发
- [Kotlin for Android](https://developer.android.com/kotlin)
- [Android Permissions Guide](https://developer.android.com/training/permissions)

### iOS 开发
- [Swift Programming Language](https://docs.swift.org/swift-book/)
- [iOS App Development](https://developer.apple.com/ios/)

---

## 🎯 当前行动项

### 立即执行（本周）

1. **完成平台配置文档** ✅
   - Android 配置指南
   - iOS 配置指南
   - 权限策略文档

2. **调研社区插件** ⏳
   - 搜索 crates.io
   - 检查 GitHub
   - 测试兼容性

3. **准备测试环境**
   - 配置 Android 模拟器
   - 配置 iOS 模拟器
   - 准备真机设备

### 近期执行（下周）

4. **集成社区插件**
   - 添加依赖
   - 更新代码
   - 基础测试

5. **真机测试**
   - Android 设备
   - iOS 设备
   - 问题修复

### 长期考虑（下月）

6. **评估自定义插件**
   - 是否有必要
   - 开发成本
   - 维护成本

---

## ✅ 成功标准

### 功能标准

- ✅ 权限请求对话框正常显示
- ✅ 用户授予权限后通知正常工作
- ✅ 用户拒绝权限后有明确提示
- ✅ 可以检查当前权限状态
- ✅ 可以引导用户到系统设置

### 体验标准

- ✅ 权限请求时机合理
- ✅ 权限说明文案清晰
- ✅ 拒绝权限后有友好提示
- ✅ 设置入口容易找到

### 技术标准

- ✅ 代码结构清晰
- ✅ 类型安全
- ✅ 错误处理完善
- ✅ 日志记录完整

---

## 📝 总结

### 当前状态

- ✅ 权限接口已定义
- ✅ 平台配置文档已完成
- ⏳ 实际实现待完成

### 推荐路径

1. **短期**: 使用社区插件快速实现
2. **中期**: 真机测试和优化
3. **长期**: 考虑自定义插件

### 预期时间

- 社区插件集成: 1-2 天
- 真机测试: 2-3 天
- 自定义插件（可选）: 1-2 周

**总计**: 3-5 天完成基本功能，1-2 周完成完整实现

---

**文档版本**: v1.0  
**最后更新**: 2024-12-06  
**维护者**: Cascade AI
