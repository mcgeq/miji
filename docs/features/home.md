# Home

> 中文版：[home.zh.md](home.zh.md) · [← Feature guides](README.md)

Home is the dashboard you land on between the two data-heavy modules. Its job is to answer "how am I doing?" in one glance and to get you into a quick action in as few taps as possible.

The layout is responsive: a **single column on phones**, and an **8/4 two-column layout** on tablets and desktops.

## Sections

| Section | What it shows |
| --- | --- |
| **Greeting header** | Time-aware greeting and the month selector |
| **Balance hero** | The headline number — this month's remaining budget, or the month's net when there is no budget — plus a time-vs-spend progress bar and a breakdown (used / daily allowance / income) |
| **Alerts strip** | Anything that needs attention now (bills due, budget alerts) |
| **Insight strip** | A one-line observation ("spending is 18% up vs last period", "you spent faster than time elapsed") |
| **Overview card** | Income / expense / net for the month |
| **Weekly trend** | A small bar chart of recent spending |
| **Category structure** | Where the money went, by category and sub-category |
| **Spending calendar** | A heatmap-style month calendar; tap a day to add a back-dated transaction |
| **Recent transactions** | The latest activity, tappable through to detail |
| **Health strip** | A slim glance at the current cycle status |
| **Stat tiles** | A compact set of secondary metrics |
| **Quick actions** | Shortcuts into the most common entry flows |
| **Onboarding** | A first-run view shown when there is nothing to display yet |

## Behaviour notes

- The hero number adapts: **budget mode** shows what is left to spend this month (counting committed amounts), **no-budget mode** falls back to the month's net.
- Every amount respects the global **hide amounts** switch, and income amounts are masked by default (tap an income amount to reveal — see the bookkeeping guide).
- The layout is designed so conditional blocks never cause the page to jump; empty states keep the same footprint as populated ones.

## Related docs & source

- Source: `lib/features/home/`
