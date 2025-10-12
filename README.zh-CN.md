# 米记 (Miji)

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tauri](https://img.shields.io/badge/Tauri-2.0-blue.svg)](https://tauri.app/)
[![Vue](https://img.shields.io/badge/Vue-3.5-green.svg)](https://vuejs.org/)
[![Rust](https://img.shields.io/badge/Rust-2024-orange.svg)](https://www.rust-lang.org/)

一个基于 Tauri 和 Rust 构建的模块化跨平台生产力和健康管理应用。

[English](./README.md) | [中文](./README.zh-CN.md)

</div>

## 📖 简介

米记是一款现代化、轻量级的桌面应用程序，帮助您在一个地方管理日常任务、财务和健康数据。以性能和隐私为核心设计理念，米记使用 SQLite 在本地存储所有数据，确保您的信息安全且可离线访问。

## ✨ 功能特性

- 📝 **待办管理** - 通过项目、标签和清单组织您的任务
- 💰 **账本记录** - 详细分类追踪您的收入和支出
- 🏥 **健康监测** - 记录和监控各种健康指标
- 🏷️ **标签系统** - 灵活的标签系统，便于更好地组织
- 📊 **项目管理** - 轻松管理多个项目
- 🌍 **国际化** - 完整支持中文和英文
- 🎨 **现代界面** - 使用 UnoCSS 构建的美观响应式界面
- 🔒 **隐私优先** - 所有数据本地存储，带有安全认证
- 🚀 **跨平台** - 支持 Windows、macOS 和 Linux

## 🛠️ 技术栈

### 前端
- **框架**: Vue 3 with `<script setup>` 和 TypeScript
- **构建工具**: Vite
- **路由**: Vue Router 自动导入
- **状态管理**: Pinia
- **UI 样式**: UnoCSS with Tailwind preset
- **表单验证**: Vee-Validate + Zod
- **图标**: Lucide Vue + Iconify (Tabler icons)
- **日期处理**: date-fns
- **国际化**: Vue I18n

### 后端
- **框架**: Tauri 2
- **语言**: Rust (Edition 2024)
- **数据库**: SQLite with SeaORM
- **认证**: JWT + Argon2 密码哈希
- **日志**: tracing + tauri-plugin-log

### 开发工具
- **代码检查**: ESLint + Biome
- **代码格式化**: Biome
- **Git 钩子**: Husky + lint-staged
- **提交规范**: Commitizen + Commitlint
- **测试**: Vitest

## 📋 环境要求

开始之前，请确保已安装以下工具：

- **Node.js**: v18 或更高版本
- **Bun**: 最新版本（或 npm/yarn/pnpm）
- **Rust**: 最新稳定版本
- **系统依赖**: 参考 [Tauri 环境配置指南](https://tauri.app/v2/guides/prerequisites/)

### 平台特定要求

#### Windows
- Microsoft Visual Studio C++ Build Tools
- WebView2（Windows 10/11 通常预装）

#### macOS
- Xcode Command Line Tools

#### Linux
- 依赖项因发行版而异，参见 [Tauri Linux 配置](https://tauri.app/v2/guides/prerequisites/#linux)

## 🚀 快速开始

### 安装

1. **克隆仓库**
   ```bash
   git clone https://github.com/yourusername/miji.git
   cd miji
   ```

2. **安装依赖**
   ```bash
   bun install
   ```

### 开发

以开发模式运行应用：

```bash
bun run tauri dev
```

这将启动 Vite 开发服务器并启动 Tauri 应用程序，启用热重载功能。

### 构建

构建生产版本应用：

```bash
bun run tauri build
```

编译后的应用程序将位于 `src-tauri/target/release/bundle/` 目录中。

## 📂 项目结构

```
miji/
├── src/                      # 前端源代码
│   ├── assets/              # 静态资源（样式、图片）
│   ├── components/          # 可复用的 Vue 组件
│   │   └── common/         # 通用 UI 组件
│   ├── composables/         # Vue 组合式函数
│   ├── features/            # 功能模块
│   │   ├── auth/           # 认证
│   │   ├── health/         # 健康追踪
│   │   ├── money/          # 财务管理
│   │   ├── projects/       # 项目管理
│   │   ├── settings/       # 应用设置
│   │   ├── tags/           # 标签系统
│   │   └── todos/          # 待办管理
│   ├── i18n/               # 国际化
│   ├── locales/            # 翻译文件（中英文）
│   ├── pages/              # 页面组件
│   ├── router/             # Vue Router 配置
│   ├── schema/             # Zod 验证模式
│   ├── services/           # API 服务
│   ├── stores/             # Pinia 状态管理
│   ├── types/              # TypeScript 类型定义
│   ├── utils/              # 工具函数
│   └── main.ts             # 应用入口点
│
├── src-tauri/               # Tauri/Rust 后端
│   ├── crates/             # 功能 crates
│   │   ├── auth/          # 认证模块
│   │   ├── healths/       # 健康模块
│   │   ├── money/         # 财务模块
│   │   └── todos/         # 待办模块
│   ├── common/            # 共享工具
│   ├── entity/            # SeaORM 实体
│   ├── migration/         # 数据库迁移
│   ├── src/               # 主应用代码
│   └── Cargo.toml         # Rust 依赖
│
├── public/                 # 公共资源
├── dist/                   # 构建输出
└── package.json           # Node.js 依赖
```

## 🔧 开发脚本

```bash
# 运行开发服务器
bun run dev

# 构建生产版本
bun run build

# 预览生产构建
bun run preview

# 运行 Tauri 开发模式
bun run tauri dev

# 构建 Tauri 应用
bun run tauri build

# 运行测试
bun run test

# 代码检查
bun run lint

# 修复代码检查问题
bun run lint:fix

# 格式化代码
bun run format

# 使用 Commitizen 提交
bun run commit
```

## 🏗️ 架构设计

### 前端架构

米记采用基于功能的架构，每个主要功能都组织在自己的模块中：

- **Components**: 可复用的 UI 组件
- **Composables**: 共享的 Vue 组合式函数
- **Services**: API 通信层
- **Stores**: 使用 Pinia 进行状态管理
- **Schema**: 使用 Zod 进行数据验证

### 后端架构

Rust 后端组织为工作空间 crates：

- **Common**: 共享工具和类型
- **Entity**: SeaORM 数据库模型
- **Migration**: 数据库模式迁移
- **Crates**: 功能特定模块（auth、todos、money、healths）

### 数据库

- **ORM**: SeaORM
- **数据库**: SQLite
- **迁移**: 应用启动时自动迁移

## 🌐 国际化

米记开箱即支持多语言：

- English (en)
- 简体中文 (zh)

翻译文件位于 `src/locales/` 目录。添加新语言的步骤：

1. 在 `src/locales/` 中创建新的 JSON 文件
2. 更新 `src/i18n/i18n.ts` 中的 i18n 配置
3. 在设置中添加语言选项

## 🔐 安全性

- **密码哈希**: Argon2 算法
- **认证**: 基于 JWT 的令牌系统
- **数据存储**: 所有数据存储在加密的本地 SQLite 数据库中
- **安全通信**: 无外部数据传输

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request。

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 使用 commitizen 提交更改 (`bun run commit`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启一个 Pull Request

## 📝 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 👨‍💻 作者

**mcgeq**

## 🙏 致谢

- [Tauri](https://tauri.app/) - 提供了出色的框架
- [Vue.js](https://vuejs.org/) - 渐进式 JavaScript 框架
- [Rust](https://www.rust-lang.org/) - 强大的系统编程语言
- [SeaORM](https://www.sea-ql.org/SeaORM/) - 优雅的数据库 ORM

---

<div align="center">
用 ❤️ 制作 by mcgeq
</div>

