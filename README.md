# Miji (米记)

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tauri](https://img.shields.io/badge/Tauri-2.5-blue.svg)](https://tauri.app/)
[![Vue](https://img.shields.io/badge/Vue-3.5-green.svg)](https://vuejs.org/)
[![Tailwind](https://img.shields.io/badge/Tailwind-4.0-06B6D4.svg)](https://tailwindcss.com/)

A privacy-focused personal management app for finance, health, and productivity.

[English](./README.md) | [中文](./README-ZH-CN.md)

</div>

## 💡 About

**Miji** (米记) is a cross-platform desktop application built with **Tauri 2**, **Vue 3**, and **Rust**. 

All data is stored locally in SQLite - no cloud sync, no tracking, complete privacy.

## ✨ Features

**💰 Finance**
- Multi-account & multi-currency support
- Transaction tracking with categories
- Budget planning & reminders
- Family ledger with expense splitting
- Charts & statistics

**📝 Productivity**
- Task & project management
- Priorities & tags
- Checklists & subtasks

**🏥 Health**
- Period tracking & calendar
- Daily health records
- Statistics & trends

**🎨 Experience**
- Modern UI with Tailwind CSS v4
- Dark mode & responsive design
- Multi-language (English/中文)

**🔒 Security**
- Local-first (no cloud sync)
- RBAC permission system
- Encrypted data storage

## 🛠️ Tech Stack

**Frontend:** Vue 3 · TypeScript · Tailwind CSS v4 · Vite

**Backend:** Tauri 2 · Rust · SQLite · SeaORM

**Tools:** Biome · Vitest · Husky

## 🚀 Quick Start

### Prerequisites

- Node.js 20+ · Rust 1.70+ · [Tauri prerequisites](https://tauri.app/v2/guides/prerequisites/)

### Installation

```bash
# Clone repository
git clone https://github.com/mcgeq/miji.git
cd miji

# Install dependencies
bun install

# Run development mode
bun run tauri dev

# Build for production
bun run tauri build
```

## 📝 Development

```bash
# Scripts
npm run tauri dev    # Development mode
npm run tauri build  # Production build
npm run lint         # Code linting
npm run test         # Run tests
```

## 📂 Structure

```
src/          # Frontend (Vue 3 + Tailwind CSS v4)
src-tauri/    # Backend (Rust + Tauri 2)
```

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**mcgeq**

---

<div align="center">
Made with ❤️ by mcgeq
</div>
