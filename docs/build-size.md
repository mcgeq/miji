# 安装包体积优化说明

> 适用端：Android（主）、iOS
> 命令示例使用 `flutter build`；如需查看体积构成可用 `--analyze-size`。

## 1. 体积构成（Android arm64，release）

| 组成 | 大小 | 说明 |
| --- | --- | --- |
| `lib/arm64-v8a/libapp.so` | ≈14.2 MB | Dart AOT 快照（业务 + Flutter 框架），release 已开启 tree-shaking |
| `lib/arm64-v8a/libflutter.so` | ≈11.6 MB | Flutter 引擎，固定成本 |
| `lib/arm64-v8a/libsqlite3.so` | ≈1.7 MB | 本地数据库（`sqlite3_flutter_libs` 自带 SQLite） |
| `classes.dex` + `classes2.dex` | ≈1.6 MB | Java/Kotlin（已启用 R8） |
| `res/` + `resources.arsc` | ≈0.25 MB | Android 资源（已限制语言） |
| `assets/` | ≈0.24 MB | Flutter 资源，含 `NOTICES.Z`（开源许可，无法移除） |

**结论**：约 **96% 的体积来自 `libapp.so` + `libflutter.so`**，属于 Flutter 应用的固定/半固定成本，难以显著压缩；真正可观的优化来自**分发格式**与**资源/依赖裁剪**。

## 2. 关键：分发格式（最大收益）

| 产物 | 体积 | 用户实际下载 |
| --- | --- | --- |
| fat APK（含 arm64 + armeabi-v7a + x86_64） | ≈81 MB | 81 MB（含无用 ABI） |
| 按 ABI 拆分 APK | 26–30 MB / 个 | 26–30 MB |
| AAB（App Bundle，含全部 ABI） | ≈74 MB | 由商店按设备下发，约 27–30 MB |

**发布建议**：
- 上架 Google Play / 支持 AAB 的商店：`flutter build appbundle --release`
- 直接分发 APK：`flutter build apk --release --split-per-abi`（按 ABI 分发对应包）
- **不要分发 `app-release.apk`（fat）**，除非确需兼容所有 ABI。

## 3. 已实施的优化

### 3.1 移除零引用依赖
`connectivity_plus`、`flutter_svg`（含 `vector_graphics*`）、`google_fonts`、`local_auth`、`logger` 在 `lib/` 中零引用，已从 `pubspec.yaml` 移除（连同 16 个传递依赖）。
> 注：Dart 侧未引用代码本就被 tree-shaking 丢弃，因此对 `libapp.so` 影响很小；主要收益是减少原生插件（dex / so）与依赖面。

### 3.2 开启 R8 与资源压缩
`android/app/build.gradle.kts` release 构建新增：
- `isMinifyEnabled = true`（代码压缩/混淆）
- `isShrinkResources = true`（移除未引用资源）
- `proguardFiles(... "proguard-rules.pro")`

`android/app/proguard-rules.pro` 仅保留必要的反射规则（`flutter_local_notifications` 使用 Gson 反射反序列化已调度通知）。**注意**：规则过宽（如 `-keepattributes InnerClasses,EnclosingMethod` 或 `-keep class com.google.gson.** { *; }`）会让 dex 反而变大，已按最小集收敛。

### 3.3 裁剪 Android 资源语言
`defaultConfig` 新增 `resourceConfigurations += listOf("zh", "en")`，剔除第三方库携带的其它语言字符串，`resources.arsc` 由 ≈0.12 MB 降至 ≈0.05 MB。

### 3.4 图标 tree-shaking（默认已开启）
构建日志显示 `MaterialIcons-Regular.otf` 减少 96.1%、`CupertinoIcons.ttf` 减少 99.7%（仅保留实际用到的字形）。保留 `cupertino_icons` 依赖可避免框架引用的 Cupertino 图标缺失。

## 4. 进一步可选项（按风险排序）

| 选项 | 预估收益 | 风险 | 说明 |
| --- | --- | --- | --- |
| 仅分发 AAB / ABI 拆分 | 81 MB → 27 MB | 无 | **首选**，见第 2 节 |
| 提升 `minSdk` 至 26+ 并关闭 core library desugaring | ≈0.5 MB | 中 | 依赖 `flutter_local_notifications` 是否仍需 desugaring；会缩小设备覆盖 |
| 用系统 SQLite 替代内置 `libsqlite3.so` | ≈1.7 MB | 高 | Android 的 `libsqlite.so` 非公开 NDK 接口，版本/特性不可控，本地优先财务数据不建议 |
| 进一步裁剪 Dart 依赖 / 移除功能模块 | 数百 KB 起 | 中 | 需权衡功能 |
| iOS：`--split-debug-info` + App Thinning | — | 低 | iOS 由 App Store 自动做设备变体下发 |

## 5. 复现与验证

```bash
# 依赖与静态检查
flutter pub get
flutter analyze

# 单 ABI 体积（用于回归对比）
flutter build apk --release --target-platform android-arm64

# 分发产物
flutter build appbundle --release
flutter build apk --release --split-per-abi

# 体积构成分析（生成 treemap / JSON）
flutter build apk --release --analyze-size --target-platform android-arm64
```

> 提示：启用 R8/资源压缩后，发布前应在真机做一次冒烟测试（尤其本地通知、定时通知、数据库、分享、图片选择等涉及原生插件的路径）。
