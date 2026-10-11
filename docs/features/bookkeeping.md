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
- **Credit / debt**: balance is the amount used/owed.
- **Inactive**: hidden from daily use but kept for history.

Balances are never edited directly. To make the books match reality, use **balance reconciliation** (see below).

### Transaction (`MoneyTransaction`)

A transaction is one of three types:

- **Expense** / **Income** — carry a category and (for expenses) a payment method.
- **Transfer** — moves money between two accounts; carries no category.

A transaction also has a status: **completed**, **pending** (recorded but not yet affecting the balance or statistics) or **voided**. Each transaction can carry a name, notes, merchant, location, tags, and a refund amount. Deleting moves it to the **recycle bin** (kept for 30 days).

### Category (`MoneyCategory` / `MoneySubCategory`)

Two levels: a top-level category and sub-categories. Each has a name, colour and icon. There are built-in seed categories, plus user-defined ones. Categories can be deactivated instead of deleted.

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

### Auto-posting template (`MoneyAutoPostingTemplate`)

A template generates a transaction on a schedule (e.g. rent on the 1st). If a plan ends up double-recording the same repayment, the template can be **taken over** by the installment (deactivated), and Miji flags the conflict.

### Bill reminder (`MoneyBillReminder`)

Recurring reminders for credit-card repayments and other bills. Completing a reminder can post a transaction; the reminder centre aggregates everything due.

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
