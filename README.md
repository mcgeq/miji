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

Miji is a modern, lightweight desktop application that helps you manage your daily tasks, finances, and health data all in one place. Built with performance and privacy in mind, Miji stores all your data locally using SQLite, ensuring your information remains secure and accessible offline.

## ✨ Features

- 📝 **Todo Management** - Organize your tasks with projects, tags, and checklists
- 💰 **Money Tracking** - Track your income and expenses with detailed categorization
- 🏥 **Health Monitoring** - Record and monitor various health metrics
- 🏷️ **Tag System** - Flexible tagging system for better organization
- 📊 **Project Management** - Manage multiple projects with ease
- 🌍 **Internationalization** - Full support for English and Chinese (中文)
- 🎨 **Modern UI** - Beautiful and responsive interface built with UnoCSS
- 🔒 **Privacy First** - All data stored locally with secure authentication
- 🚀 **Cross-Platform** - Runs on Windows, macOS, and Linux

## 🛠️ Tech Stack

### Frontend
- **Framework**: Vue 3 with `<script setup>` and TypeScript
- **Build Tool**: Vite
- **Router**: Vue Router with auto-import
- **State Management**: Pinia
- **UI Styling**: UnoCSS with Tailwind preset
- **Form Validation**: Vee-Validate + Zod
- **Icons**: Lucide Vue + Iconify (Tabler icons)
- **Date Handling**: date-fns
- **I18n**: Vue I18n

### Backend
- **Framework**: Tauri 2
- **Language**: Rust (Edition 2024)
- **Database**: SQLite with SeaORM
- **Authentication**: JWT with Argon2 password hashing
- **Logging**: tracing + tauri-plugin-log

### Development Tools
- **Linting**: ESLint + Biome
- **Formatting**: Biome
- **Git Hooks**: Husky + lint-staged
- **Commit Convention**: Commitizen + Commitlint
- **Testing**: Vitest

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js**: v18 or higher
- **Bun**: Latest version (or npm/yarn/pnpm)
- **Rust**: Latest stable version
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
   bun install
   ```

### Development

Run the application in development mode:

```bash
bun run tauri dev
```

This will start the Vite dev server and launch the Tauri application with hot-reload enabled.

### Building

Build the application for production:

```bash
bun run tauri build
```

The compiled application will be available in `src-tauri/target/release/bundle/`.

## 📂 Project Structure

```
miji/
├── src/                      # Frontend source code
│   ├── assets/              # Static assets (styles, images)
│   ├── components/          # Reusable Vue components
│   │   └── common/         # Common UI components
│   ├── composables/         # Vue composables
│   ├── features/            # Feature modules
│   │   ├── auth/           # Authentication
│   │   ├── health/         # Health tracking
│   │   ├── money/          # Finance management
│   │   ├── projects/       # Project management
│   │   ├── settings/       # Application settings
│   │   ├── tags/           # Tag system
│   │   └── todos/          # Todo management
│   ├── i18n/               # Internationalization
│   ├── locales/            # Translation files (en, zh)
│   ├── pages/              # Page components
│   ├── router/             # Vue Router configuration
│   ├── schema/             # Zod validation schemas
│   ├── services/           # API services
│   ├── stores/             # Pinia stores
│   ├── types/              # TypeScript type definitions
│   ├── utils/              # Utility functions
│   └── main.ts             # Application entry point
│
├── src-tauri/               # Tauri/Rust backend
│   ├── crates/             # Feature crates
│   │   ├── auth/          # Authentication module
│   │   ├── healths/       # Health module
│   │   ├── money/         # Finance module
│   │   └── todos/         # Todo module
│   ├── common/            # Shared utilities
│   ├── entity/            # SeaORM entities
│   ├── migration/         # Database migrations
│   ├── src/               # Main application code
│   └── Cargo.toml         # Rust dependencies
│
├── public/                 # Public assets
├── dist/                   # Build output
└── package.json           # Node.js dependencies
```

## 🔧 Development Scripts

```bash
# Run development server
bun run dev

# Build for production
bun run build

# Preview production build
bun run preview

# Run Tauri dev mode
bun run tauri dev

# Build Tauri app
bun run tauri build

# Run tests
bun run test

# Lint code
bun run lint

# Fix linting issues
bun run lint:fix

# Format code
bun run format

# Commit with Commitizen
bun run commit
```

## 🏗️ Architecture

### Frontend Architecture

Miji follows a feature-based architecture where each major feature is organized in its own module:

- **Components**: Reusable UI components
- **Composables**: Shared Vue composition functions
- **Services**: API communication layer
- **Stores**: State management with Pinia
- **Schema**: Data validation with Zod

### Backend Architecture

The Rust backend is organized into workspace crates:

- **Common**: Shared utilities and types
- **Entity**: SeaORM database models
- **Migration**: Database schema migrations
- **Crates**: Feature-specific modules (auth, todos, money, healths)

### Database

- **ORM**: SeaORM
- **Database**: SQLite
- **Migrations**: Automatic migration on application start

## 🌐 Internationalization

Miji supports multiple languages out of the box:

- English (en)
- 简体中文 (zh)

Translation files are located in `src/locales/`. To add a new language:

1. Create a new JSON file in `src/locales/`
2. Update the i18n configuration in `src/i18n/i18n.ts`
3. Add the language option in settings

## 🔐 Security

- **Password Hashing**: Argon2 algorithm
- **Authentication**: JWT-based token system
- **Data Storage**: All data stored locally in encrypted SQLite database
- **Secure Communication**: No external data transmission

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes using commitizen (`bun run commit`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**mcgeq**

## 🙏 Acknowledgments

- [Tauri](https://tauri.app/) - For the amazing framework
- [Vue.js](https://vuejs.org/) - For the progressive JavaScript framework
- [Rust](https://www.rust-lang.org/) - For the powerful systems programming language
- [SeaORM](https://www.sea-ql.org/SeaORM/) - For the elegant database ORM

---

<div align="center">
Made with ❤️ by mcgeq
</div>
