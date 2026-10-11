# Settings

> 中文版：[settings.zh.md](settings.zh.md) · [← Feature guides](README.md)

Settings groups everything that isn't a daily task: your account, how the app looks, module defaults, and how your data is backed up.

## Sections

| Section | Contents |
| --- | --- |
| **Account & security** | Profile (avatar, name, email), change password, log out |
| **Appearance & display** | Theme mode (light / dark / system), hide amounts, health hint |
| **Bookkeeping preferences** | Default currency and the bookkeeping module's base parameters (plus reminder settings) |
| **Data & sync** | WebDAV, local encrypted snapshots, delta sync diagnostics, legacy import |
| **About** | Version and the local-first data note |

## Data & sync

This is the most involved section. It covers four things:

- **WebDAV configuration** — point Miji at a WebDAV server, set a sync password, and choose whether to sync on startup and whether to run automatic incremental sync.
- **Local encrypted snapshots** — create, inspect and restore snapshots of the whole database. Restoring asks you to sign in again afterwards.
- **Delta sync diagnostics** — the device identity, pending local changes, the remote cursor and the conflict count, so you can see whether sync is healthy.
- **Legacy import** — a one-off import of old desktop-edition bookkeeping data.

Sync is **opt-in and encrypted**: nothing leaves the device unless you configure a target and trigger it.

## Privacy switches

- **Hide amounts** masks every amount in the app. Individual amounts can still be revealed from the account menu (per-account), and **income amounts are masked independently by default** (see the [bookkeeping guide](bookkeeping.md)).
- **Health hint** toggles the slim cycle strip on the Home dashboard.

## Related docs & source

- Source: `lib/features/settings/`
- Sync internals: `lib/core/sync/`
