# Miji (米记)

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tauri](https://img.shields.io/badge/Tauri-2.0-blue.svg)](https://tauri.app/)
[![Vue](https://img.shields.io/badge/Vue-3.5-green.svg)](https://vuejs.org/)
[![Rust](https://img.shields.io/badge/Rust-2024-orange.svg)](https://www.rust-lang.org/)

A modular, cross-platform productivity and health management application built with Tauri and Rust.

[English](./README.md) | [中文](./README.zh-CN.md)

</div>

## 📖 Introduction

Miji (米记) is a modern, privacy-focused desktop application for managing your daily life. Track your finances, monitor your health, organize tasks, and manage projects - all in one beautiful, cross-platform application.

Built with **Tauri 2**, **Vue 3**, and **Rust**, Miji combines the performance of native applications with the flexibility of modern web technologies. All your data is stored locally in SQLite, ensuring complete privacy and offline access.

## ✨ Features

### 💰 Finance Management
- **Multi-Account Support** - Manage multiple accounts with different currencies
- **Transaction Tracking** - Record income, expenses, and transfers with categories
- **Budget Planning** - Set and monitor budgets with spending alerts
- **Bill Reminders** - Never miss a payment with recurring reminders
- **Family Ledger** - Shared family accounting with member management and expense splitting
- **Statistics & Charts** - Visualize your financial data with ECharts

### 📝 Todo & Project Management
- **Task Organization** - Create, organize, and track tasks with priorities
- **Project Hierarchies** - Manage projects with nested tasks
- **Tags & Categories** - Flexible tagging for better organization
- **Checklists** - Break down complex tasks into smaller steps

### 🏥 Health Tracking
- **Period Tracking** - Monitor menstrual cycles with calendar view
- **Daily Health Records** - Track various health metrics
- **Health Statistics** - Visualize trends and patterns

### 🎨 User Experience
- **Modern UI** - Beautiful, responsive interface with smooth animations
- **Dark Mode** - Easy on the eyes with automatic theme switching
- **Multi-Language** - Full support for English and Chinese (中文)
- **Keyboard Shortcuts** - Boost productivity with hotkeys

### 🔒 Privacy & Security
- **Local-First** - All data stored locally, no cloud sync
- **Secure Authentication** - JWT-based auth with Argon2 password hashing
- **Data Encryption** - Sensitive data encrypted at rest
- **Offline Access** - Works completely offline

## 🛠️ Tech Stack

### Frontend
- **Framework**: Vue 3.5 with Composition API (`<script setup>`)
- **Language**: TypeScript 5.8 (strict mode)
- **Build Tool**: Vite 7
- **Router**: Vue Router 4 with unplugin-vue-router (auto-import)
- **State Management**: Pinia 3 (modular stores)
- **Form Validation**: Vee-Validate + Zod
- **UI Components**: Custom components with Lucide icons
- **Charts**: Vue ECharts
- **Date Handling**: date-fns 4
- **I18n**: Vue I18n 11
- **Utilities**: VueUse, es-toolkit

### Backend
- **Framework**: Tauri 2.5
- **Language**: Rust 2024 Edition
- **Database**: SQLite 3 with SeaORM 1.1
- **Authentication**: JWT (jsonwebtoken) + Argon2 password hashing
- **Logging**: tracing + tauri-plugin-log
- **Background Tasks**: Tokio async runtime with scheduled jobs
- **Plugins**: Auto-start, Dialog, FS, Notification, OS, SQL

### Development Tools
- **Linting**: ESLint 9 (@antfu/eslint-config) + Biome 2.2
- **Formatting**: Biome
- **Git Hooks**: Husky 9 + lint-staged
- **Commit Convention**: Commitizen + Commitlint (Gitmoji)
- **Testing**: Vitest 3
- **Type Checking**: vue-tsc
- **Auto Import**: unplugin-auto-import + unplugin-vue-components

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js**: v20 or higher (recommended: v22)
- **Package Manager**: npm, yarn, pnpm, or bun
- **Rust**: 1.70 or higher (with cargo)
- **System Dependencies**: Follow the [Tauri prerequisites guide](https://tauri.app/v2/guides/prerequisites/)

### Platform-Specific Requirements

#### Windows
- Microsoft Visual Studio C++ Build Tools
- WebView2 (usually pre-installed on Windows 10/11)

#### macOS
- Xcode Command Line Tools

#### Linux
- Dependencies vary by distribution. See [Tauri Linux setup](https://tauri.app/v2/guides/prerequisites/#linux)

## 🚀 Getting Started

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/miji.git
   cd miji
   ```

2. **Install dependencies**
   ```bash
   npm install
   # or
   bun install
   ```

### Development

Run the application in development mode:

```bash
npm run tauri dev
# or
bun run tauri dev
```

This will:
1. Start the Vite dev server (http://localhost:9428)
2. Launch the Tauri application
3. Enable hot-reload for both frontend and backend changes

**First run**: The Rust backend will compile, which may take a few minutes.

### Building

Build the application for production:

```bash
npm run tauri build
# or
bun run tauri build
```

The compiled application will be available in:
- **Windows**: `src-tauri/target/release/bundle/msi/` or `nsis/`
- **macOS**: `src-tauri/target/release/bundle/dmg/` or `macos/`
- **Linux**: `src-tauri/target/release/bundle/deb/`, `appimage/`, or `rpm/`

## 📂 Project Structure

```
miji/
├── src/                          # Frontend (Vue 3 + TypeScript)
│   ├── assets/                  # Static assets (CSS, images)
│   ├── bootstrap/               # App initialization modules
│   │   ├── stores.ts           # Pinia store initialization
│   │   ├── router.ts           # Router setup
│   │   └── schedulers.ts       # Background job schedulers
│   ├── components/              # Reusable Vue components
│   │   └── common/             # Generic UI components
│   ├── composables/             # Vue composables (hooks)
│   │   ├── useAccountActions.ts
│   │   ├── useTransactionActions.ts
│   │   ├── useBudgetActions.ts
│   │   └── ...
│   ├── features/                # Feature modules (domain logic)
│   │   ├── auth/               # Authentication & user management
│   │   ├── health/             # Period & health tracking
│   │   ├── home/               # Dashboard & home views
│   │   ├── money/              # Finance management
│   │   │   ├── components/    # Money-specific components
│   │   │   ├── composables/   # Money-specific composables
│   │   │   ├── utils/         # Money utilities
│   │   │   └── views/         # Money views
│   │   ├── projects/           # Project management
│   │   ├── settings/           # App settings
│   │   ├── tags/               # Tag system
│   │   └── todos/              # Todo management
│   ├── i18n/                    # I18n configuration
│   ├── layouts/                 # Layout components
│   ├── locales/                 # Translation files (en, zh)
│   ├── pages/                   # Auto-generated page routes
│   ├── router/                  # Vue Router setup
│   ├── schema/                  # Zod schemas & TypeScript types
│   ├── services/                # API service layer
│   │   ├── money/              # Money services (MoneyDb)
│   │   ├── healths/            # Health services
│   │   └── todo.ts             # Todo services
│   ├── stores/                  # Pinia stores (state management)
│   │   ├── money/              # Modular money stores
│   │   │   ├── account-store.ts
│   │   │   ├── transaction-store.ts
│   │   │   ├── budget-store.ts
│   │   │   ├── reminder-store.ts
│   │   │   ├── category-store.ts
│   │   │   ├── family-ledger-store.ts
│   │   │   ├── family-member-store.ts
│   │   │   ├── family-split-store.ts
│   │   │   └── money-errors.ts
│   │   ├── periodStore.ts      # Health/period store
│   │   ├── todoStore.ts        # Todo store
│   │   └── ...
│   ├── types/                   # TypeScript types & interfaces
│   ├── utils/                   # Utility functions
│   ├── App.vue                  # Root component
│   └── main.ts                  # Application entry point
│
├── src-tauri/                    # Backend (Rust + Tauri 2)
│   ├── crates/                  # Modular Rust crates
│   │   ├── auth/               # Authentication module
│   │   │   ├── src/commands.rs # Tauri commands
│   │   │   └── src/lib.rs
│   │   ├── healths/            # Health tracking module
│   │   ├── money/              # Finance module
│   │   └── todos/              # Todo module
│   ├── common/                  # Shared utilities
│   │   ├── db_utils.rs         # Database helpers
│   │   ├── error.rs            # Error handling
│   │   └── types.rs            # Common types
│   ├── entity/                  # SeaORM database entities
│   ├── migration/               # Database migrations
│   ├── src/                     # Main application
│   │   ├── commands.rs         # Tauri commands registry
│   │   ├── lib.rs              # Library root
│   │   ├── main.rs             # Application entry
│   │   └── schedulers.rs       # Background job schedulers
│   ├── Cargo.toml              # Rust dependencies
│   └── tauri.conf.json         # Tauri configuration
│
├── public/                       # Public static files
├── dist/                         # Build output (generated)
├── package.json                  # Node.js dependencies & scripts
├── vite.config.ts               # Vite configuration
├── tsconfig.json                # TypeScript configuration
└── README.md                     # This file
```

## 🔧 Development Scripts

```bash
# Development
npm run dev              # Start Vite dev server only
npm run tauri dev        # Start full Tauri app with hot-reload

# Building
npm run build            # Build frontend only
npm run tauri build      # Build complete Tauri app
npm run preview          # Preview production build

# Code Quality
npm run lint             # Run ESLint + Biome checks
npm run lint:fix         # Auto-fix linting issues
npm run format           # Format code with Biome

# Testing
npm run test             # Run Vitest tests

# Git & Commits
npm run commit           # Commit with Commitizen (interactive)
npm run prepare          # Setup Husky git hooks

# Tauri specific
npm run tauri            # Run Tauri CLI commands
```

## 🏗️ Architecture

### Frontend Architecture

Miji follows a **modular, feature-based architecture** for maintainability and scalability:

#### Core Principles
1. **Feature Modules**: Each domain (money, health, todos) is self-contained
2. **Composition API**: Leverages Vue 3's Composition API for logic reuse
3. **Type Safety**: Strict TypeScript with Zod schema validation
4. **Modular Stores**: Pinia stores split by domain (not monolithic)
5. **Service Layer**: Clean separation between UI and data access

#### Key Patterns
- **Composables**: Reusable logic (e.g., `useAccountActions`, `useFilters`)
- **Services**: Direct database access via Tauri commands (e.g., `MoneyDb`)
- **Stores**: Reactive state management with getters and actions
- **Components**: Presentational components with clear props/events

#### Recent Improvements
- ✅ **Store Refactoring**: Split monolithic `moneyStore` into 5 modular stores:
  - `account-store` (165 lines) - Account management
  - `transaction-store` (282 lines) - Transactions & transfers
  - `budget-store` (149 lines) - Budget tracking
  - `reminder-store` (182 lines) - Bill reminders
  - `category-store` (138 lines) - Categories with caching
- ✅ **Error Handling**: Unified error handling with `MoneyStoreError`
- ✅ **Performance**: ~20% improvement with optimized stores
- ✅ **Type Safety**: 100% TypeScript coverage in strict mode

### Backend Architecture

Rust backend organized as a **workspace** with modular crates:

#### Workspace Structure
```rust
[workspace]
members = [
    "crates/auth",      // JWT auth, user management
    "crates/todos",     // Todo & project CRUD
    "crates/money",     // Finance tracking
    "crates/healths",   // Health records
]
```

#### Core Components
- **Commands**: Tauri IPC commands exposed to frontend
- **Services**: Business logic layer
- **Entities**: SeaORM models (database schema)
- **Migrations**: Versioned database migrations
- **Schedulers**: Background jobs (e.g., installment processing)

#### Key Features
- **Async Runtime**: Tokio for concurrent operations
- **Database Pool**: Efficient connection management
- **Error Propagation**: Custom error types with context
- **Logging**: Structured logging with `tracing`

### Database Architecture

- **Database**: SQLite 3 (file-based, portable)
- **ORM**: SeaORM 1.1 (async, type-safe)
- **Migrations**: Auto-run on startup (via `migration` crate)
- **Schema**:
  - Users & authentication
  - Accounts, transactions, budgets, categories
  - Family ledgers, members, split rules, debt relations
  - Todos, projects, tags
  - Health records (periods, daily records)
  - System settings

### Performance Optimizations

1. **Frontend**:
   - Modular stores (reduce reactivity overhead)
   - Smart caching (CategoryStore: 5-min cache)
   - Lazy loading (features loaded on demand)
   - Virtual scrolling (for large lists)

2. **Backend**:
   - Connection pooling
   - Indexed database queries
   - Batch operations (bulk inserts)
   - Background job scheduling

## 🌐 Internationalization

Miji supports multiple languages with Vue I18n:

- **English** (en-US)
- **简体中文** (zh-CN)

### Translation Files
```
src/locales/
├── en.json    # English translations
└── zh.json    # Chinese translations
```

### Adding a New Language

1. Create translation file:
   ```bash
   cp src/locales/en.json src/locales/ja.json
   ```

2. Update i18n config in `src/i18n/i18n.ts`:
   ```typescript
   import ja from '@/locales/ja.json'
   
   const i18n = createI18n({
     legacy: false,
     locale: 'en',
     messages: { en, zh, ja },
   })
   ```

3. Add to settings UI

### Usage in Components
```vue
<script setup>
const { t } = useI18n()
</script>

<template>
  <h1>{{ t('common.appName') }}</h1>
</template>
```

## 🔐 Security

### Authentication
- **Password Hashing**: Argon2id (memory-hard, GPU-resistant)
- **Token System**: JWT with RS256 (asymmetric signing)
- **Session Management**: Secure token storage and refresh
- **Rate Limiting**: Brute-force protection on login

### Data Security
- **Local Storage**: All data stored in local SQLite database
- **No Cloud Sync**: Zero data transmission to external servers
- **Encryption**: Sensitive fields encrypted at rest
- **Access Control**: User-based data isolation

### Application Security
- **CSP**: Content Security Policy enabled
- **Input Validation**: Zod schemas validate all inputs
- **SQL Injection**: SeaORM prevents SQL injection
- **XSS Protection**: Vue.js auto-escapes templates

### Privacy
- **No Analytics**: No usage tracking or telemetry
- **No Ads**: Completely ad-free
- **Open Source**: Transparent and auditable code

## 🤝 Contributing

Contributions are welcome! Follow these steps:

### Setup
1. **Fork** the repository
2. **Clone** your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/miji.git
   cd miji
   ```
3. **Install** dependencies:
   ```bash
   npm install
   ```
4. **Create** a feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```

### Development
1. **Make** your changes
2. **Test** thoroughly:
   ```bash
   npm run lint
   npm run test
   npm run tauri dev
   ```
3. **Commit** with Commitizen:
   ```bash
   npm run commit
   ```
   (Follows Gitmoji convention)

### Submission
1. **Push** to your fork:
   ```bash
   git push origin feature/amazing-feature
   ```
2. **Open** a Pull Request
3. **Wait** for review

### Guidelines
- Follow existing code style (ESLint + Biome)
- Add tests for new features
- Update documentation if needed
- Keep commits atomic and well-described
- Use Gitmoji for commit messages

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**mcgeq**

## 🙏 Acknowledgments

### Frameworks & Libraries
- [Tauri](https://tauri.app/) - Amazing Rust-powered framework
- [Vue.js](https://vuejs.org/) - Progressive JavaScript framework
- [Rust](https://www.rust-lang.org/) - Systems programming language
- [SeaORM](https://www.sea-ql.org/SeaORM/) - Elegant async ORM
- [Pinia](https://pinia.vuejs.org/) - Intuitive state management
- [Vite](https://vitejs.dev/) - Lightning-fast build tool

### UI & Icons
- [Lucide](https://lucide.dev/) - Beautiful open-source icons
- [ECharts](https://echarts.apache.org/) - Powerful charting library
- [VueUse](https://vueuse.org/) - Collection of Vue Composition utilities

### Tools
- [Biome](https://biomejs.dev/) - Fast formatter and linter
- [Vitest](https://vitest.dev/) - Blazing fast unit test framework
- [TypeScript](https://www.typescriptlang.org/) - Typed JavaScript

### Special Thanks
To all open-source contributors who make projects like this possible!

---

<div align="center">
Made with ❤️ by mcgeq
</div>
