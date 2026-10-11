<p align="center">
  <a href="README-zh.md">中文</a> · <strong>English</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20macOS-lightgrey" alt="Platforms">
</p>

# Miji

A **local-first, cross-platform personal life app** built with Flutter — bookkeeping, health tracking, habit check-ins and tasks in one place.

There is no account and no server: everything is stored in a local SQLite database, with optional encrypted WebDAV backup. Miji works offline, and your data never leaves the device unless you explicitly back it up.

## Modules

Miji is organised into five modules, reachable from the bottom navigation (plus a global quick-action button):

| Module | What it covers | Guide |
| --- | --- | --- |
| 📒 **Bookkeeping** | Accounts, income / expense / transfers, categories & tags, budgets, statistics, installments, auto-posting, bill reminders, splitting, ledgers | [docs/features/bookkeeping.md](docs/features/bookkeeping.md) |
| 🩺 **Health** | Menstrual-cycle tracking & prediction, a rich daily log, trend charts, pregnancy mode | [docs/features/health.md](docs/features/health.md) |
| ✅ **Check-in & Tasks (GTD)** | Habit / plan check-ins, task management, a unified calendar and statistics | [docs/features/gtd.md](docs/features/gtd.md) |
| 🏠 **Home** | A one-glance dashboard: net worth, budget pace, spending trends, recent activity, quick entry | [docs/features/home.md](docs/features/home.md) |
| ⚙️ **Settings** | Account & security, appearance, module preferences, WebDAV sync, legacy import | [docs/features/settings.md](docs/features/settings.md) |
| 🔐 **Auth & security** | Local login, app lock (PIN / pattern), secondary verification for sensitive pages | [docs/features/auth-security.md](docs/features/auth-security.md) |

## Screenshots

|                 Home (Light / Dark)                  |                  Account (Light / Dark)                  |
| :--------------------------------------------------: | :------------------------------------------------------: |
| ![home-light](scriptures/home-light.jpg) | ![account-light](scriptures/account-light.jpg) |
|  ![home-dark](scriptures/home-dark.jpg)  |  ![account-dark](scriptures/account-dark.jpg)  |

## Tech Stack

| Layer            | Technology                                                |
| ---------------- | --------------------------------------------------------- |
| Framework        | Flutter + Dart 3.12                                       |
| State management | Riverpod 3.x + riverpod_annotation                        |
| Navigation       | GoRouter 17.x                                             |
| Database         | Drift (SQLite ORM) + sqlite3                              |
| Code generation  | freezed, json_serializable, riverpod_generator, drift_dev |
| Charts           | fl_chart                                                  |
| Calendar         | table_calendar                                            |
| Theming          | flex_color_scheme (Material 3)                            |
| Notifications    | flutter_local_notifications                               |
| Security         | flutter_secure_storage, local_auth, cryptography          |
| Icons            | flutter_svg + vector_graphics_compiler                    |
| Fonts            | Google Fonts                                              |

## Getting Started

```bash
git clone <repo-url>
cd miji
flutter pub get
dart run build_runner build
flutter run
```

Supported platforms: Android, iOS, Web, Windows, macOS.

## Project Structure

```
lib/
├── core/
│   ├── attachments/     # Shared attachment storage
│   ├── auth/            # Session & app-lock state
│   ├── database/        # Drift schema, migrations, seeds
│   ├── notifications/   # Local notification service
│   ├── ocr/             # On-device text recognition (receipts)
│   ├── preferences/     # User preferences
│   ├── presentation/    # Shared UI components
│   ├── router/          # Route configuration
│   ├── security/        # Password hashing
│   ├── sync/            # WebDAV sync, delta sync, snapshots
│   ├── theme/           # Design tokens & theming
│   └── user/            # User entity & repository
├── features/
│   ├── auth/            # Register / login / unlock
│   ├── bookkeeping/     # Bookkeeping module
│   ├── gtd/             # Check-in, plans, GTD shell
│   ├── health/          # Health-tracking module
│   ├── home/            # Dashboard
│   ├── settings/        # Settings pages
│   ├── shell/           # App shell & navigation
│   └── todo/            # Tasks & task statistics
└── shared/
    └── widgets/         # Reusable form widgets
```

## Documentation

- **Feature guides** — [`docs/features/`](docs/features/README.md)
- **Open tasks (backlog, 中文)** — [`docs/open-tasks.md`](docs/open-tasks.md)
- **Bookkeeping requirements** — [`docs/specs/bookkeeping-requirements.md`](docs/specs/bookkeeping-requirements.md)
- **Bookkeeping roadmap (feature gaps)** — [`docs/specs/bookkeeping-feature-gaps-and-roadmap.md`](docs/specs/bookkeeping-feature-gaps-and-roadmap.md)

## License

MIT
