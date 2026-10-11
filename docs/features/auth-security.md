# Auth & Security

> 中文版：[auth-security.zh.md](auth-security.zh.md) · [← Feature guides](README.md)

Miji has **no server and no account recovery** — everything is local. Security therefore has three layers: a local account, an optional app lock, and a short-lived unlock for the most sensitive pages.

## Local account

A user registers with a username / email and a password. Passwords are never stored in plain text: they are hashed with **PBKDF2** and the credentials are kept in encrypted storage (`flutter_secure_storage`), not in the plain database.

Miji supports **multiple local users** on one device. Most state (preferences, hidden-account choices, caches) is keyed by user id, so switching users does not leak one user's settings or data into another's session.

## App lock

An optional lock protects the app after you leave it. Two methods:

| Method | Notes |
| --- | --- |
| **PIN** | A 6-digit code |
| **Pattern** | An Android-style gesture pattern |

The lock validates the secret's shape (digit count, pattern length, duplicate/invalid nodes) and can be disabled. When the app is locked, the session is kept but the UI is gated behind the unlock page.

## Sensitive-access verification

Even inside an unlocked app, the two most sensitive modules — **bookkeeping** and **health** — can require a second verification before they render. Once passed, the unlock is valid for a configurable **TTL**:

`10 minutes` (default) · `1 hour` · `3 hours` · `12 hours` · `30 days` · `90 days` · `forever`

This keeps a shared or handed-over device from exposing financial or health data on a casual glance, without asking for a password on every tap.

## Related docs & source

- Source: `lib/core/auth/`, `lib/features/auth/`
- Security helpers: `lib/core/security/`
