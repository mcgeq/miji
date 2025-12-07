# Miji (米记)

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tauri](https://img.shields.io/badge/Tauri-2.5-blue.svg)](https://tauri.app/)
[![Vue](https://img.shields.io/badge/Vue-3.5-green.svg)](https://vuejs.org/)
[![Rust](https://img.shields.io/badge/Rust-2024-orange.svg)](https://www.rust-lang.org/)
[![Tailwind](https://img.shields.io/badge/Tailwind-4.0-06B6D4.svg)](https://tailwindcss.com/)

**Privacy-First Personal Management Platform**

A modular, cross-platform desktop application for finance, health, and productivity management.

[English](./README.md) | [中文](./README-ZH-CN.md)

</div>

## 💡 About

**Miji** (米记) is a modern, modular personal management platform built with **Tauri 2**, **Vue 3**, and **Rust**.

### Core Principles

🔒 **Privacy-First** - All data stored locally in SQLite, zero cloud dependencies  
🎯 **Modular Architecture** - Independent feature modules with clean boundaries  
⚡ **High Performance** - Rust backend + reactive Vue frontend  
🌍 **Cross-Platform** - Windows, macOS, Linux, Android, iOS support  
🎨 **Modern Design** - Tailwind CSS v4 with dark mode

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

## 🏗️ Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer (Vue 3)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Money   │  │  Todos   │  │  Health  │  │   Auth   │   │
│  │ Features │  │ Features │  │ Features │  │ Features │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                   State Management (Pinia)                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Money   │  │   Todo   │  │  Period  │  │   Auth   │   │
│  │  Stores  │  │  Stores  │  │  Stores  │  │  Stores  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│               Tauri IPC Bridge (Commands)                    │
└─────────────────────────────────────────────────────────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                   Backend Layer (Rust)                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Money   │  │  Todos   │  │ Healths  │  │   Auth   │   │
│  │  Crate   │  │  Crate   │  │  Crate   │  │  Crate   │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        └─────────────┴─────────────┴─────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 Database Layer (SQLite)                      │
│                     via SeaORM                               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌─ User Action ─────────────────────────────────────────────┐
│                                                             │
│  1. User clicks "Add Transaction"                          │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─ UI Component ───────────────────────────────────────────┐
│                                                            │
│  2. TransactionModal.vue                                   │
│     - Form validation (Zod schema)                         │
│     - Data preparation                                     │
└──────────────────────┬─────────────────────────────────────┘
                       ▼
┌─ State Management ───────────────────────────────────────┐
│                                                            │
│  3. Pinia Store (moneyStore.ts)                            │
│     - Optimistic update                                    │
│     - Cache management                                     │
└──────────────────────┬─────────────────────────────────────┘
                       ▼
┌─ API Service ────────────────────────────────────────────┐
│                                                            │
│  4. transactionDb.ts                                       │
│     - Type conversion                                      │
│     - Request packaging                                    │
└──────────────────────┬─────────────────────────────────────┘
                       ▼
┌─ IPC Bridge ─────────────────────────────────────────────┐
│                                                            │
│  5. Tauri Commands                                         │
│     - invoke('transaction_create', payload)                │
└──────────────────────┬─────────────────────────────────────┘
                       ▼
┌─ Rust Backend ───────────────────────────────────────────┐
│                                                            │
│  6. Money Crate                                            │
│     ├─ Commands (command.rs)                              │
│     ├─ Services (service.rs)                              │
│     └─ DTOs (dto.rs)                                       │
└──────────────────────┬─────────────────────────────────────┘
                       ▼
┌─ Database ───────────────────────────────────────────────┐
│                                                            │
│  7. SQLite via SeaORM                                      │
│     - Transaction insert                                   │
│     - Relation handling                                    │
│     - Response generation                                  │
└──────────────────────┬─────────────────────────────────────┘
                       ▼
┌─ Response Flow ──────────────────────────────────────────┐
│                                                            │
│  8. Data flows back through:                               │
│     Backend → IPC → Service → Store → UI                  │
│                                                            │
│  9. UI updates:                                            │
│     - Transaction list refreshes                           │
│     - Statistics update                                    │
│     - Charts re-render                                     │
└────────────────────────────────────────────────────────────┘
```

## 🛠️ Tech Stack

### Frontend

| Category | Technologies |
|----------|-------------|
| **Framework** | Vue 3.5 (Composition API, TypeScript) |
| **State Management** | Pinia 3.0 with TypeScript |
| **Router** | Vue Router 4 with typed routes |
| **UI Framework** | Tailwind CSS 4.0 (latest) |
| **Forms** | Vee-Validate + Zod schemas |
| **Icons** | Lucide Vue Next |
| **Charts** | Apache ECharts |
| **I18n** | Vue I18n 11 |
| **Build Tool** | Vite 8.0 (beta) with Rolldown |
| **Utilities** | es-toolkit, date-fns, @vueuse/core |

### Backend

| Category | Technologies |
|----------|-------------|
| **Runtime** | Tauri 2.5 |
| **Language** | Rust 2024 Edition |
| **Database** | SQLite 3 |
| **ORM** | SeaORM 1.1 with migrations |
| **Async Runtime** | Tokio 1.45 |
| **Serialization** | Serde + serde_json |
| **Validation** | Validator 0.20 |
| **Security** | Argon2 password hashing |
| **Logging** | tracing + tracing-subscriber |

### Development Tools

| Category | Technologies |
|----------|-------------|
| **Linter/Formatter** | Biome 2.3 (replaces ESLint + Prettier) |
| **Testing** | Vitest 3.2 |
| **Type Checking** | TypeScript 5.8 + vue-tsc |
| **Git Hooks** | Husky + lint-staged |
| **Commit Convention** | Commitizen + Commitlint |
| **Package Manager** | Bun (recommended) or npm |

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

### Available Scripts

```bash
# Development
bun run tauri:dev      # Start development server
bun run dev            # Frontend only (Vite dev)

# Building
bun run tauri:build    # Production build
bun run build          # Type check + Vite build
bun run build:win      # Windows specific build
bun run build:android  # Android build
bun run build:ios      # iOS build

# Code Quality
bun run lint           # Check code with Biome
bun run lint:fix       # Auto-fix issues
bun run fmt:all        # Format all code (TS + Rust)
bun run test           # Run tests

# Commits
bun run commit         # Interactive commit (Commitizen)
bun run jjc            # Jujutsu commit helper
```

### Development Workflow

1. **Start Development Server**
   ```bash
   bun run tauri:dev
   ```
   - Hot reload enabled
   - DevTools available
   - Backend logs in terminal

2. **Make Changes**
   - Frontend: Changes auto-reload
   - Backend: Requires restart (Ctrl+C → re-run)

3. **Testing**
   ```bash
   bun run test         # Unit tests
   bun run lint         # Code quality
   ```

4. **Commit Changes**
   ```bash
   # Using Jujutsu (Recommended)
   jj new -m "feat: add new feature"
   jj git push
   
   # Or using Git
   bun run commit       # Interactive commit
   git push
   ```

### Version Control

This project supports both **Jujutsu** and **Git** version control systems (colocate mode):

```bash
# Using Jujutsu (Recommended)
jj status           # View status
jj commit -m "msg"  # Commit changes
jj git push         # Push to GitHub

# Or using Git (Traditional)
git status
git commit -m "msg"
git push
```

**New machine or fresh clone?**
```bash
git clone https://github.com/mcgeq/miji.git
cd miji
jj git init --colocate  # Initialize Jujutsu
jj bookmark track main@origin
# ✅ All history auto-imported from .git/, nothing lost!
```

📖 Guides:
- [Quick Reference](./docs/JUJUTSU_QUICK_REFERENCE.md) - Cheat sheet ⭐
- [New Machine Setup](./docs/JUJUTSU_NEW_MACHINE_SETUP.md) - Must read
- [Branch Operations](./docs/JUJUTSU_BRANCH_GUIDE.md) - Branch management

## 📂 Project Structure

```
miji/
├── src/                          # Frontend source code
│   ├── features/                 # Feature modules
│   │   ├── money/               # Finance management
│   │   │   ├── components/      # Money UI components
│   │   │   ├── composables/     # Money logic hooks
│   │   │   ├── stores/          # Money state stores
│   │   │   └── types/           # Money TypeScript types
│   │   ├── todos/               # Task management
│   │   ├── health/              # Health tracking
│   │   └── auth/                # Authentication
│   ├── components/              # Shared UI components
│   │   ├── ui/                  # Base UI components
│   │   └── common/              # Common components
│   ├── composables/             # Shared composition functions
│   ├── stores/                  # Global Pinia stores
│   ├── router/                  # Vue Router configuration
│   ├── i18n/                    # Internationalization
│   ├── utils/                   # Utility functions
│   ├── schema/                  # Zod validation schemas
│   └── services/                # API service layer
│
├── src-tauri/                    # Backend source code
│   ├── src/                     # Main application
│   │   ├── commands/            # Tauri command handlers
│   │   ├── plugins/             # Plugin initialization
│   │   └── lib.rs               # Application entry
│   ├── crates/                  # Feature crates
│   │   ├── money/               # Finance backend
│   │   │   ├── command.rs       # Money commands
│   │   │   ├── service.rs       # Money business logic
│   │   │   └── dto.rs           # Money data transfer objects
│   │   ├── todos/               # Task backend
│   │   ├── healths/             # Health backend
│   │   └── auth/                # Auth backend
│   ├── entity/                  # Database entities (SeaORM)
│   ├── migration/               # Database migrations
│   ├── common/                  # Shared utilities
│   └── Cargo.toml               # Rust dependencies
│
├── docs/                         # Documentation
├── public/                       # Static assets
└── dist/                        # Build output
```

### Module Organization

Each feature module follows a consistent structure:

**Frontend Module** (`src/features/{feature}/`):
- `components/` - UI components specific to the feature
- `composables/` - Reusable composition functions
- `stores/` - Pinia state management
- `types/` - TypeScript type definitions
- `views/` - Page-level components

**Backend Crate** (`src-tauri/crates/{feature}/`):
- `command.rs` - Tauri command handlers (IPC layer)
- `service.rs` - Business logic implementation
- `dto.rs` - Data transfer objects
- `error.rs` - Error types and handling
- `lib.rs` - Module exports

## � Documentation

- 📖 [Architecture](./docs/ARCHITECTURE.md) - System architecture and data flow
- 🗄️ [Database Schema](./docs/database/README.md) - Database design and tables
- 🔄 [Version Control](./docs/JUJUTSU_QUICK_REFERENCE.md) - Jujutsu quick reference
- 🛠️ [ES-Toolkit Usage](./docs/ES_TOOLKIT_QUICK_REFERENCE.md) - Utility functions guide

## 🎯 Key Features

### Money Management
- **Multi-Currency**: Support for 100+ currencies with live exchange rates
- **Smart Categories**: Auto-categorization with custom rules
- **Family Ledger**: Expense splitting with multiple allocation methods
- **Budget Tracking**: Real-time budget monitoring with alerts
- **Reports**: Comprehensive charts and statistics

### Task Management
- **Smart Todos**: Priority-based with deadline reminders
- **Projects**: Organize tasks into projects with tags
- **Recurring Tasks**: Flexible recurrence patterns
- **Subtasks**: Break down complex tasks
- **Batch Operations**: Quick actions on multiple items

### Health Tracking
- **Period Tracking**: Calendar view with predictions
- **Symptom Logging**: Detailed health records
- **Statistics**: Trend analysis and insights
- **Reminders**: Smart notifications

## 🔧 Advanced Features

- ⚡ **Offline-First**: Works completely offline, no internet required
- 🔒 **Data Security**: AES encryption for sensitive data
- 🌐 **I18n**: English and Chinese with easy extension
- 🎨 **Theming**: Light/Dark mode with system preference sync
- 📱 **Responsive**: Optimized for all screen sizes
- 🚀 **Performance**: Fast startup (<1s) and smooth interactions

## �📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**mcgeq**

---

<div align="center">
Made with ❤️ by mcgeq
</div>
