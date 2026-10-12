# Home

> 中文版：[home.zh.md](home.zh.md) · [← Feature guides](README.md)

Home is a "life dashboard" that puts **money / health / action** side by side. Its job is to answer "how am I doing?" in one glance and to get you into a quick action in as few taps as possible.

## Layout

- **Horizontal pager (default)**: four pages `Overview / Money / Health / Action`, switched by swiping left/right, with page dots at the bottom. The top tab bar is off by default and can be enabled in settings.
  - **Wraps around**: swiping past `Action` returns to `Overview`, and swiping back from `Overview` goes to `Action` — no dead ends at either end. Tapping a tab takes the shortest path (Overview → Action steps back one page instead of sweeping across three).
- **Vertical single column**: one scroll; tablets and desktops (≥840dp) use an 8/4 two-column layout.
- Switch under **Settings → Home → Layout**. Both layouts share the same block configuration.

## Sections

| Section | What it shows |
| --- | --- |
| **Greeting header** | Time-aware greeting, streak and month selector |
| **Today board** | Money / health / action side by side: remaining budget (or month net), period/pregnancy status, today's todo progress. Each cell can be turned off (at least 2 remain) |
| **Up next · Today's todos** | Up to 3 todos on the overview page, checkable inline; "view all" opens GTD |
| **Unified reminders** | Money / todo / habit / health pending items in one place, sorted by urgency (overdue → today → within 3 days → normal); each row is directly actionable |
| **Money · Budget hero** | Budget / trend / calendar combined into one card |
| **Money · Categories** | Collapsed to a one-line summary by default; tap to expand |
| **Money · Recent** | Collapsed to the latest transaction by default; tap to expand |
| **Health · Cycle** | Cycle ring + current phase + days until next period / late / pregnancy week; an enable guide when tracking is off |
| **Health · Today** | Mood / sleep / water / weight, tap any to log in place |
| **Health · 7-day forecast** | Off by default. A 7-day strip: period / fertile / PMS / normal |
| **Action · Today's todos** | Complete, add, edit or delete inline; overdue and priority are marked |
| **Action · Habits** | Progress + one-tap check-in + streak |
| **Net worth** | Assets − liabilities |
| **Insight strip** | Cross-module observations: money ("spending is 18% up vs last period"), action ("82% done this week"), health ("sleeping 6h40m on average") — each tappable |
| **Onboarding** | A money / health / action three-module guide shown on first run |

## Behaviour notes

- The money cell adapts: **budget mode** shows what is left to spend this month, **no-budget mode** falls back to the month's net. A cell with no data shows `—` instead of hiding the whole board.
- The health blocks collapse into a single "enable health tracking" guide when period tracking is off.
- Every amount respects the global **hide amounts** switch, and income amounts are masked by default (tap an income amount to reveal — see the bookkeeping guide).
- The layout is designed so conditional blocks never cause the page to jump; empty states keep the same footprint as populated ones.

## Related docs & source

- Source: `lib/features/home/`
- Design: [`../specs/home-dashboard-v2-design.md`](../specs/home-dashboard-v2-design.md)
