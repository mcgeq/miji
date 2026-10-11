<p align="center">
  <strong>中文</strong> · <a href="README.md">English</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20macOS-lightgrey" alt="Platforms">
</p>

# 米记 Miji

**本地优先的跨平台个人生活应用**，用 Flutter 构建 —— 记账、健康、打卡与待办，一个 App 全包。

没有账号、没有服务端：所有数据都存在本地 SQLite 里，可选加密 WebDAV 备份。完全离线可用，除非你主动备份，数据不会离开设备。

## 功能模块

应用分为五个模块，位于底部导航（外加一个全局快速新增按钮）：

| 模块 | 覆盖内容 | 指南 |
| --- | --- | --- |
| 📒 **记账** | 账户、收支转账、分类与标签、预算、统计、分期、自动记账、账单提醒、分摊、账本 | [docs/features/bookkeeping.zh.md](docs/features/bookkeeping.zh.md) |
| 🩺 **健康** | 经期记录与预测、完整的每日健康日志、趋势图表、怀孕模式 | [docs/features/health.zh.md](docs/features/health.zh.md) |
| ✅ **打卡与待办** | 习惯 / 计划打卡、任务管理、统一日历与统计 | [docs/features/gtd.zh.md](docs/features/gtd.zh.md) |
| 🏠 **首页** | 一眼看懂：净资产、预算节奏、支出趋势、最近动态、快捷记账 | [docs/features/home.zh.md](docs/features/home.zh.md) |
| ⚙️ **设置** | 账户与安全、外观、各模块偏好、WebDAV 同步、旧数据导入 | [docs/features/settings.zh.md](docs/features/settings.zh.md) |
| 🔐 **认证与安全** | 本地登录、应用锁（PIN / 手势）、敏感页二次验证 | [docs/features/auth-security.zh.md](docs/features/auth-security.zh.md) |

## 界面截图

|                 首页（浅色 / 深色）                  |                  账户（浅色 / 深色）                   |
| :--------------------------------------------------: | :------------------------------------------------------: |
| ![home-light](scriptures/home-light.jpg) | ![account-light](scriptures/account-light.jpg) |
|  ![home-dark](scriptures/home-dark.jpg)  |  ![account-dark](scriptures/account-dark.jpg)  |

## 技术栈

| 层       | 技术                                                      |
| -------- | --------------------------------------------------------- |
| 框架     | Flutter + Dart 3.12                                       |
| 状态管理 | Riverpod 3.x + riverpod_annotation                        |
| 路由     | GoRouter 17.x                                             |
| 数据库   | Drift (SQLite ORM) + sqlite3                              |
| 代码生成 | freezed, json_serializable, riverpod_generator, drift_dev |
| 图表     | fl_chart                                                  |
| 日历     | table_calendar                                            |
| 主题     | flex_color_scheme (Material 3)                            |
| 通知     | flutter_local_notifications                               |
| 安全     | flutter_secure_storage, local_auth, cryptography          |
| 图标     | flutter_svg + vector_graphics_compiler                    |
| 字体     | Google Fonts                                              |

## 开始使用

```bash
git clone <repo-url>
cd miji
flutter pub get
dart run build_runner build
flutter run
```

平台支持：Android、iOS、Web、Windows、macOS。

## 项目结构

```
lib/
├── core/
│   ├── attachments/     # 共享附件存储
│   ├── auth/            # 会话与应用锁状态
│   ├── database/        # Drift 库表、迁移与种子数据
│   ├── notifications/   # 本地通知服务
│   ├── ocr/             # 端侧文字识别（小票）
│   ├── preferences/     # 用户偏好
│   ├── presentation/    # 共享 UI 组件
│   ├── router/          # 路由配置
│   ├── security/        # 密码哈希
│   ├── sync/            # WebDAV 同步、增量同步、快照
│   ├── theme/           # 设计 token 与主题
│   └── user/            # 用户实体与仓储
├── features/
│   ├── auth/            # 注册 / 登录 / 解锁
│   ├── bookkeeping/     # 记账模块
│   ├── gtd/             # 打卡、计划与 GTD 外壳
│   ├── health/          # 健康追踪模块
│   ├── home/            # 首页仪表盘
│   ├── settings/        # 设置页面
│   ├── shell/           # 应用外壳与导航
│   └── todo/            # 任务与任务统计
└── shared/
    └── widgets/         # 可复用表单组件
```

## 文档

- **功能指南** —— [`docs/features/`](docs/features/README.zh.md)
- **未完成任务清单（backlog）** —— [`docs/open-tasks.md`](docs/open-tasks.md)
- **记账需求说明** —— [`docs/specs/bookkeeping-requirements.md`](docs/specs/bookkeeping-requirements.md)
- **记账功能缺口与路线图** —— [`docs/specs/bookkeeping-feature-gaps-and-roadmap.md`](docs/specs/bookkeeping-feature-gaps-and-roadmap.md)

## 许可证

MIT
