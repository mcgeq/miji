# Bookkeeping

> 中文版：[bookkeeping.zh.md](bookkeeping.zh.md) · [← Feature guides](README.md)

The bookkeeping module is Miji's largest: it tracks **where the money is** (accounts), **what happened** (transactions), **where it is going** (budgets) and **what it looks like** (statistics), plus the machinery that keeps all of that consistent (installments, auto-posting, reminders).

It opens on the **Transactions** tab. The module is split into five panels:

| Panel | Purpose |
| --- | --- |
| **Transactions** | The full ledger list, with search, type/status/date/tag filters, bulk actions and a recycle bin |
| **Accounts** | Account list grouped into assets / credit & debt / inactive, plus net worth |
| **Budgets** | Budget tracking with periods, scopes, allocations and alerts |
| **Statistics** | A paged dashboard of 22 charts & cards |
| **More** | Categories, installments, auto-posting, reminders |

## Core concepts

### Ledger (`MoneyLedger`)

Everything belongs to a ledger. There are two kinds:

- **Personal ledger** — created automatically for every user.
- **Family ledger** — shared among members (used for splitting).

The ledger selector lives in the top bar (compact screens) or the page toolbar. Every transaction carries the ledgers it belongs to.

### Account (`MoneyAccount`)

An account is a place money sits. Types include cash, bank cards, Alipay, WeChat, Huabei, Baitiao, credit cards, loans, investments, and an internal system account. Accounts carry a currency, an initial balance, a current balance and optional credit metadata (limit, statement day, repayment day, budget cycle start day).

- **Assets**: balance is the money you have.
- **Credit / debt**: credit shows available limit, a loan shows the outstanding amount (positive).
- **Inactive**: hidden from daily use but kept for history.

Cards are rendered by **semantic group**, not by the 16 account types: spendable balance (cash / bank / savings / wallets), prepaid balance, credit limit, debt, holdings. Every group shares one skeleton — icon and name → primary value → side values → progress bar (credit usage rate for credit, repaid ratio for debt) → footer action row. Only the copy and that single progress bar differ, which keeps card height predictable. Loan accounts used to fall into the asset branch and rendered "balance −¥486,200 / initial −¥600,000"; they now render as debt: outstanding, repaid progress, principal (as entered at account creation).

Balances are never edited directly. To make the books match reality, use **balance reconciliation** (see below).

Tapping a card, or the **View transactions** icon in its footer (icon only — a tooltip and semantic label carry the name, since the footer already has one text entry and a second one would squeeze long account names into an ellipsis), opens the same account sheet (overview + filterable transactions) instead of switching panels. The sheet's overview reuses the card's monthly totals (calendar month, completed only, transfers excluded), so its caption states **"excluding transfers"** — filtering the list by account *does* include the two transfer legs (out / in). Bulk re-categorisation and cross-account search still only exist in the full transactions panel, so the sheet keeps that as a secondary **icon** button (`list_alt`, "View all in transactions"); the sheet's only write action, "Add transaction", is an icon too (`add`, filled). Both carry their name through tooltips and semantic labels, matching the card's "View transactions" icon: text buttons wrap at 320dp, and these are object-level entries rather than the primary task of the screen.

**Date ranges become part of a provider family key, so they must be normalised to whole days.** "Last 90 days" originally subtracted 90 days from `DateTime.now()`, whose milliseconds differ every frame — a new key every frame, the provider destroyed and rebuilt over and over, and the list stuck on a spinner. Ranges now start at midnight; the statement period is normalised the same way.

**Masking stops outside the sheet.** "Hide amounts" is a global preference, and each account can override it (explicit show > explicit hide > global). That state applies to **the card only**: the account sheet is a detail view the user deliberately opened, so it always shows real amounts, as does the transaction detail reached from it. Two reasons — the sheet has no eye toggle, so a masked user has no second switch to unmask it; and "I opened it and it is still ••••, and tapping does nothing" reads as a bug. The scope (`MoneyPrivacyScope`) still sits directly under `ProviderScope`, not inside the shell: dialogs live on the root navigator and cannot see a shell-level scope, so they silently fall back to "not masked".

### Transaction (`MoneyTransaction`)

A transaction is one of three types:

- **Expense** / **Income** — carry a category and (for expenses) a payment method.
- **Transfer** — moves money between two accounts; carries no category.

A transaction also has a status: **completed**, **pending** (recorded but not yet affecting the balance or statistics) or **voided**. Each transaction can carry a name, notes, merchant, location, tags, and a refund amount. Deleting moves it to the **recycle bin** (kept for 30 days).

### Category (`MoneyCategory` / `MoneySubCategory`)

Two levels: a top-level category and sub-categories. Each has a name, colour and icon. There are built-in seed categories, plus user-defined ones. Categories can be deactivated instead of deleted.

The **categories panel** (under "More") is a full-screen category list with a docked entry bar; its header holds only the expense/income segmented control, search and category management — no title and no back button. It is a panel within the module: the panel name is already shown by the toolbar chip on wide screens and the two-state picker in the bottom bar on narrow ones, and switching panels happens there too, so duplicating them here only costs a line of vertical space (the old "Categories" + back header did exactly that). Expanding search reuses the empty middle slot rather than adding a row.

### Tags

Transactions can carry tags. **Expense transactions are single-tag** (one tag string), which keeps tag-based budgets unambiguous. Tag candidates come from past transactions and existing budget tags, so you can pick instead of typing.

### Budget (`MoneyBudget`)

A budget tracks spending (or income) against a target. It combines:

- a **period**: daily / weekly / monthly / billing cycle / yearly / one-time (fixed date range);
- a **scope**: all / by category / by account / category + account / by tag;
- a **tracking type**: expense limit or income target;
- optional **allocations** (split the budget across sub-categories or members) and **rollover** of leftover amount.

Budgets show an execution bar, a pace hint (spending faster/slower than time), alerts near the threshold, and the amount already **committed** by auto-posting or installments.

### Installment plan (`MoneyInstallmentPlan`)

A plan freezes a principal on a credit account and generates one expense per period. Each period has a status (pending / posted / paid-off) and links to the generated transaction.

**The amount summary on each plan card is collapsed by default** (total payable / per period / remaining / principal / interest — same for active and finished plans). None of those five numbers moves: the first three are fixed the day the plan is created, and "remaining" duplicates `posted 2/12` next to the progress bar. Shown permanently they cost three rows of cells on a narrow screen (~190dp), turning the list into one card per screen. The **"next period" banner (date + this period's amount + post-it-now) stays on the card**, because it is the only thing that changes and the only thing you can act on — so a collapsed card still answers "what do I do now". The toggle at the top right (`Expand amounts` / `Collapse amounts`) only governs those cells; it is unrelated to "View details", which opens the period timeline. The toggle itself rides on the **progress row** — the whole `posted x/y` line plus the bar is tappable, with a chevron that flips to show the state. That row had no interaction of its own, so using it costs no extra space and is far easier to hit than a 40dp icon in the header; the header therefore keeps only "View details", and the title no longer gets squeezed to three characters on a narrow screen.

### Auto-posting template (`MoneyAutoPostingTemplate`)

A template generates a transaction on a schedule (e.g. rent on the 1st). If a plan ends up double-recording the same repayment, the template can be **taken over** by the installment (deactivated), and Miji flags the conflict.

**The instalment and auto-posting panels keep nothing pinned at the top.** That row used to hold just a search and a create button, centred and floating at the top — a 62px empty band pushing an already short list further down. Both actions now live in a **draggable floating bar** (`BookkeepingFloatingActions`) that is **collapsed against the edge by default**:

- **Collapsed**: only a 22×40 handle flush with the screen edge. Tap it to pull the bar out, tap again to push it back; the chevron points where the bar will go. These lists are usually a few rows long, so a permanently visible 100-plus-px bar covers content, not whitespace.
- **Dragging**: hold anywhere (including the handle) to move it; release and it snaps to the nearest left/right edge (vertical position is left alone — that is the user's choice). Kept in memory only, never persisted: it is a "where do I want it right now" preference. The default spot is bottom-right, deliberately clear of the global quick-add FAB (docked centre on narrow screens, bottom-right on wide ones, where the bar sits higher).
- **Search is a toggle**: tapping the magnifier reveals the search field at the top of the page, tapping it again collapses it **and clears the keyword** — a filter that keeps filtering after the field is gone is the hardest kind of "why is my list short" to diagnose. The magnifier inside the field does the same thing; the two tooltips differ by one word ("Collapse search bar" / "Collapse search") on purpose, because identical tooltips turn "either one works" into an ambiguous tap target.

### Bill reminder (`MoneyBillReminder`)

Recurring reminders for credit-card repayments and other bills. Completing a reminder can post a transaction; the reminder centre aggregates everything due.

### Home screen widget (Android)

A **full-width** card (2 cells tall, spanning the whole row) has five bands: the label with "3 transactions · income ¥20.00" on the right; the amount in large type with a solid **"＋ 记录一笔" pill button (124×48dp)**; a **4dp budget progress bar** with a "remaining ¥1,234.56 / ¥3,000.00" line under it (which becomes "over by ¥120.00" in the warning colour once the budget breaks); and **this week / this month / daily average** in three equal columns (amounts above 1,000 use the compact `2.3k` form).

The budget bar reads the same figures as the home budget card: both the fill and the "busted" verdict use **occupied** (spent plus committed), not spent alone — when future obligations eat the whole allowance, the outcome is the same as overspending. With no budget configured the whole band collapses instead of leaving an empty groove.

Taps go to two different targets: the **button records a transaction** (`/app/bookkeeping?action=expense`, the same route notifications use), while **the rest of the card opens the app home** (`/app/home`). Checking the ledger and recording an entry are different intents.

The bands use `layout_weight` rather than plain `wrap_content`: two grid cells are usually around 200dp tall on real launchers (110dp is only the launcher's cell-sizing floor), and `wrap_content` would dump all that surplus into the bottom of the card.

It reads the **same source as the home dashboard's money cell** (`homeTodaySpendingSummaryProvider` + `formatMoneyMinor`); the widget never computes anything itself. Amount, count, masking and lock state are all resolved in Dart and written as text, so the native side only lays it out — the home screen and the home-tab cell can't drift apart.

Three hard rules:

1. **Masked means `••••` plus "金额已隐藏"** — otherwise it reads as broken. The real number is never written to `SharedPreferences` (plain text).
2. **A locked app is masked too**, with "点开解锁". Widgets can be visible on the lock screen, and the app itself is locked.
3. **Crossing midnight always shows the date.** The snapshot carries `mw_date`; the provider compares it with today and, on mismatch, relabels the card "截至 10-20" with "该更新了 · 点开刷新". Yesterday's number never poses as today's.

Refresh only happens from the app: launch, resume, data change (500ms debounce), ledger switch, mask toggle. The system's `updatePeriodMillis` (30 minutes) exists solely to catch the midnight case. See `lib/features/bookkeeping/application/money_home_widget.dart` and the design notes in `docs/specs/home-screen-widget.md`.

### Split (`MoneySplit`)

For family ledgers, an expense can be split among members with equal / fixed / percentage / weighted / custom rules.

## Main flows

### Recording a transaction

The form is ordered by how people actually fill it: **amount → category → payment method → account → date → name → notes → status → more → split**. The account and payment method lock to each other (choosing a credit-card account locks the method), and "paid by others" switches to the internal account. From the list you can also **save & continue** to record several transactions in a row.

### Balance reconciliation

Opening an account's **reconcile** action lets you compare the book balance with the real balance. It shows `opening balance + income − expense = expected balance` for a chosen window (this month / last month / last 3 months); enter the actual balance and the difference is applied through the **initial balance**, so it never creates a transaction and never pollutes statistics.

### Importing & exporting

Transactions can be exported to CSV. On Android, a **receipt screenshot** can be recognised on-device (OCR) and pre-filled into the entry form.

## Related docs & source

- Requirements: [`docs/specs/bookkeeping-requirements.md`](../specs/bookkeeping-requirements.md)
- Roadmap & feature gaps: [`docs/specs/bookkeeping-feature-gaps-and-roadmap.md`](../specs/bookkeeping-feature-gaps-and-roadmap.md)
- Source: `lib/features/bookkeeping/`
