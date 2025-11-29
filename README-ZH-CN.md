# 米记 (Miji)

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tauri](https://img.shields.io/badge/Tauri-2.5-blue.svg)](https://tauri.app/)
[![Vue](https://img.shields.io/badge/Vue-3.5-green.svg)](https://vuejs.org/)
[![Tailwind](https://img.shields.io/badge/Tailwind-4.0-06B6D4.svg)](https://tailwindcss.com/)

注重隐私的个人管理应用，涵盖财务、健康和效率管理

[English](./README.md) | [中文](./README-ZH-CN.md)

</div>

## 💡 简介

**米记** (Miji) 是一款使用 **Tauri 2**、**Vue 3** 和 **Rust** 构建的跨平台桌面应用。

所有数据本地存储在 SQLite 数据库 - 无云同步、无追踪、完全隐私。

## ✨ 功能

**💰 财务**
- 多账户与多货币支持
- 交易追踪与分类
- 预算规划与提醒
- 家庭账本与费用分摊
- 图表与统计

**📝 效率**
- 任务与项目管理
- 优先级与标签
- 检查清单与子任务

**🏥 健康**
- 生理期追踪与日历
- 每日健康记录
- 统计与趋势

**🎨 体验**
- 基于 Tailwind CSS v4 的现代界面
- 深色模式与响应式设计
- 多语言支持 (English/中文)

**🔒 安全**
- 本地优先（无云同步）
- RBAC 权限系统
- 数据加密存储

## 🛠️ 技术栈

**前端:** Vue 3 · TypeScript · Tailwind CSS v4 · Vite

**后端:** Tauri 2 · Rust · SQLite · SeaORM

**工具:** Biome · Vitest · Husky

## 🚀 快速开始

### 环境要求

- Node.js 20+ · Rust 1.70+ · [Tauri 环境要求](https://tauri.app/v2/guides/prerequisites/)

### 安装

```bash
# 克隆仓库
git clone https://github.com/mcgeq/miji.git
cd miji

# 安装依赖
bun install

# 运行开发模式
bun run tauri dev

# 构建生产版本
bun run tauri build
```

## 📝 开发

```bash
# 脚本命令
npm run tauri dev    # 开发模式
npm run tauri build  # 生产构建
npm run lint         # 代码检查
npm run test         # 运行测试
```

## 📂 结构

```
src/          # 前端 (Vue 3 + Tailwind CSS v4)
src-tauri/    # 后端 (Rust + Tauri 2)
```

## 📝 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 👨‍💻 作者

**mcgeq**

---

<div align="center">
用 ❤️ 制作 by mcgeq
</div>
