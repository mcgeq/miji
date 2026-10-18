# Feature guides

> 中文版：[README.zh.md](README.zh.md) · [← Back to project overview](../../README.md)

Miji is organised into five modules, reachable from the bottom navigation, plus a cross-cutting authentication & security layer. Each guide explains **what the module does**, its **core concepts and data model**, and its **main flows** — behaviour, not implementation. For the "why" behind a design decision, follow the links at the bottom of each guide.

| Guide | Module | One-liner |
| --- | --- | --- |
| [Bookkeeping](bookkeeping.md) | 📒 Bookkeeping | Accounts, income / expense / transfers, budgets, statistics, installments, auto-posting, bill reminders, splitting and ledgers |
| [Health](health.md) | 🩺 Health | Menstrual-cycle tracking & prediction and a rich daily health log |
| [Check-in & Tasks (GTD)](gtd.md) | ✅ Check-in & Tasks | Habit check-ins and task management, with a shared calendar and statistics |
| [Home](home.md) | 🏠 Home | The one-glance dashboard between the data modules |
| [Settings](settings.md) | ⚙️ Settings | Account & security, appearance, module preferences, WebDAV sync and legacy import |
| [Auth & Security](auth-security.md) | 🔐 Auth & Security | Local login, app lock and sensitive-page verification |

## Conventions

- Each guide exists in two files: `<name>.md` (English) and `<name>.zh.md` (Chinese), with a language switch at the top.
- Guides describe what the app does. Requirements, roadmaps and design reviews live in the parent [`docs/`](../) folder and are linked from each guide's footer.
