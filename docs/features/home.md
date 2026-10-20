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
| **Up next** | A read-only preview of the next 7 days, grouped by day (`Tomorrow · 10/21`) with a module icon and amount per row; "view all" opens the timeline |
| **Needs attention** | The **today and overdue** slice of money / todo / habit / health, sorted by urgency (overdue → today); each row is directly actionable |
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
  - Its overspend test is the same one the budget hero uses (`used + reserved > budget`), so the two can never disagree — previously the cell said "already exceeded" while the hero said "¥0.00 left to spend".
- The health blocks collapse into a single "enable health tracking" guide when period tracking is off.
- **Up next** and **Needs attention** are split by *time*, not by source: needs attention is today + overdue (actionable in place), up next is strictly from tomorrow on (read-only preview). A todo due today therefore never appears on both cards.
  - The one exception is an exceeded budget: it has no due date, it is a current state, so it stays under needs attention.
  - Todos roll over **at the query layer**: a task scheduled yesterday and left undone still shows in today's list, tagged "3 days overdue", while the stored planned date is untouched — rewriting it would lose how long it slipped. Only `scheduledDate` rolls over; recurring instances (`occurrenceDate`) do not, or a long-neglected daily task would pile up dozens of rows today.
- Every amount respects the global **hide amounts** switch, and income amounts are masked by default (tap an income amount to reveal — see the bookkeeping guide).
- The budget hero's **overspend test is `used + reserved > budget`**, shared with the money cell and the insight strip. Reserved means future obligations (auto-posting templates, instalments, pending transactions, bill reminders): once they eat the whole allowance, not a single yuan can be spent this month, which is the same outcome as really overspending — only the composition differs, and the detail rows split it into "used / reserved / over (incl. reserved)". Judging by *used* alone makes the same screen say "already exceeded" and "¥0.00 left" at once.
  - The boundary is **strictly greater than**: when `used + reserved` equals the budget exactly, nothing is left but nothing is owed, so the card reads "¥0.00 left to spend" rather than "exceeded by ¥0.00". It flips to overspent only once the total exceeds the budget by the smallest currency unit (one cent). The daily allowance is still zero there, so the practical feeling is the same — the difference is whether there is a debt.
- When the budget is **exceeded**, the hero does not only swap its background: the brand (dark graphite) and danger (dark magenta-red) gradients have almost the same lightness, so a background change alone is invisible at a glance. Three explicit signals appear instead — a solid "already exceeded" chip in the header, the ring reading the *real* occupied percentage (not clamped to 100%, or 103% would look identical to "exactly used up"), and the detail row replacing the always-zero "daily allowance" with "over by ¥X". When nothing was actually overspent and the allowance was only drained by reservations, that row reads "over (incl. reserved)" — "exceeded ¥300" next to "used ¥4,800" (budget ¥8,000) would otherwise contradict itself.
  - The progress bar still fills to the end: the excess is not drawn as an overflow segment, which would force one bar to be read two ways (0–100% and 100%+).
  - Category budgets report **exceeded** separately from **near limit**: the former turns the header into "N exceeded" and tints the whole row with an "over" suffix; the latter only tints the bar. They used to share one count and one colour.
- The layout is designed so conditional blocks never cause the page to jump; empty states keep the same footprint as populated ones.

## Related docs & source

- Source: `lib/features/home/`
- Design: [`../specs/home-dashboard-v2-design.md`](../specs/home-dashboard-v2-design.md)
