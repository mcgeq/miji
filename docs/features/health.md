# Health

> 中文版：[health.zh.md](health.zh.md) · [← Feature guides](README.md)

The health module records a user's menstrual cycle and daily wellbeing, then predicts what comes next. It is a **cycle journal**, not a medical device — every prediction is an estimate based on past records and settings.

The module opens on **Today** and has four tabs:

| Tab | Purpose |
| --- | --- |
| **Today** | Current cycle status, the day's log, and a quick way to fill it in |
| **Calendar** | A month grid with period / fertile / PMS / symptom markers, plus per-day detail |
| **Trends** | Cycle-length and period-length trends, and phase-filtered logs |
| **Settings** | Cycle parameters, reminders, data options |

## Core concepts

### Period record (`HealthPeriodRecord`)

A period is a start date, an optional end date and optional notes. Consecutive period records form cycles; the gap between two starts is the **cycle length**, and a start→end span is the **period length**.

### Cycle settings (`HealthSettings`)

The user controls:

- **Average cycle length** and **average period length** (used until there is enough history).
- Period / ovulation / PMS **reminders**, and how many days ahead to remind.
- Data options (sync / analytics).

### Prediction (`HealthPrediction`)

From settings + history, Miji estimates the **next period start/end**, the **fertile window**, and the **PMS window**, and exposes the current **cycle day** / **period day**. Each prediction records its **basis** (settings, history or pregnancy), so the UI can say why it thinks what it thinks.

### Pregnancy record (`HealthPregnancyRecord`)

A pregnancy has a start date, a due date and a status (active / completed / miscarriage / terminated). While one is active, cycle predictions switch to a pregnancy mode that tracks the **current week**.

### Daily log (`HealthDailyRecord`)

One record per day, covering:

- **Flow level** (spotting / light / medium / heavy)
- **Symptoms** — a separate list, each with a type and an intensity
- **Mood** (happy / sad / angry / anxious / calm / irritable)
- **Exercise intensity**, **sexual activity**, **contraception method**
- **Vitals & habits** — diet, water intake, sleep, weight, temperature, stress, calories
- Free-form **notes**

The same data can be entered from the Today tab or by tapping a day in the Calendar.

## Main flows

### Logging today

The Today tab shows the current status banner and the day's quick-entry controls, so the most common actions (flow, mood, symptoms, water…) are one tap away. A full sheet exposes every field.

### Reading the calendar

The month grid marks period, fertile and PMS days and any day with a record. Tapping a day opens its detail, where you can add or edit the log.

### Understanding trends

The Trends tab plots cycle length and period length over time and lets you filter logs by phase (period / PMS / fertile window / non-period), so patterns (e.g. symptoms clustering before a period) become visible.

## Related docs & source

- Source: `lib/features/health/`
- Daily-log table: `lib/core/database/tables/health/health_daily_record_tables.dart`
