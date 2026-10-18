# Check-in & Tasks (GTD)

> 中文版：[gtd.zh.md](gtd.zh.md) · [← Feature guides](README.md)

This module brings two kinds of "things to do" under one roof: **habit check-ins** (repeating plans you tick off, optionally with a photo, a timer or a target) and **tasks** (one-off to-dos with a status, priority and due date). A shared shell gives them a common calendar and statistics.

It opens on **Today** and has five panels:

| Panel | Purpose |
| --- | --- |
| **Today** | A mixed action stream: today's tasks and habit check-ins together |
| **Tasks** | The full task list, with categories, tags, filters and recurrence |
| **Habits** | Check-in plans and their progress / streaks |
| **Calendar** | A month view combining tasks and check-ins |
| **Statistics** | Task completion trends and summaries |

## Check-ins

### Plan (`CheckinPlan`)

A plan is something you want to do regularly. It carries:

- **Name, icon, colour, category** (health / study / exercise / lifestyle / anniversary / other).
- **Plan type**: cyclic (keeps repeating) or event (a single occasion).
- **Frequency**: daily / weekly / monthly / cron / once, with an optional config.
- **Target**: a numeric value and unit (e.g. "8 cups", "30 minutes").
- **Trigger mode**: button / photo / timer / location — how a check-in is confirmed.
- **Record granularity**: merged (one record a day) or detailed (many).
- **Visibility** (for records) and an optional **reminder** (time + days before).
- **Target value/unit**, an **archived** flag and a manual **sort order**.

Every plan has a kind-specific "extra" payload: drink, stool, study, exercise, photo, anniversary or general.

### Record (`CheckinRecord`)

An individual check-in, linked to a plan. Records build up a **streak** and a **progress** value against the plan's target. Photo check-ins store an image.

### Timer

Plans with a timer trigger use a running/paused timer state, so "exercise for 30 minutes" is measured rather than guessed.

## Tasks

### Task (`TodoTask`)

A task has a title, a **status**, a **priority**, an optional **scheduled date**, a **category**, **tags**, and an optional **recurrence rule**.

- **Quick create** — a title-only sheet (also used by the global quick-action button) that creates a task scheduled today.
- **Detail page** — full editing, recurrence and metadata.
- **List** — search, filter by status/date, and group.
- **Statistics** — completion trends over the last 7 / 30 days or the current month.

## Main flows

### Your day

The **Today** panel interleaves today's tasks and habit check-ins, so one screen answers "what's left to do". Completing a check-in or a task removes it from the list; a collapsible section keeps what you already finished.

### Managing plans

The **Habits** panel lists your plans with progress. A plan can be created, edited, archived or inspected (with its record history) from the plan pages.

## Related docs & source

- Source: `lib/features/gtd/` (check-ins, plans, shell) and `lib/features/todo/` (tasks, statistics)
