---
version: alpha
name: Expense Tracker
description: A calm, trustworthy personal finance dashboard for recording expenses, understanding spending habits, and staying within monthly budgets.

colors:
  primary: "#2563EB"
  on-primary: "#FFFFFF"
  primary-container: "#DBEAFE"
  on-primary-container: "#1E3A8A"

  secondary: "#0F766E"
  on-secondary: "#FFFFFF"
  secondary-container: "#CCFBF1"
  on-secondary-container: "#134E4A"

  tertiary: "#7C3AED"
  on-tertiary: "#FFFFFF"
  tertiary-container: "#EDE9FE"
  on-tertiary-container: "#4C1D95"

  neutral: "#F8FAFC"
  background: "#F8FAFC"
  surface: "#FFFFFF"
  surface-muted: "#F1F5F9"
  on-surface: "#0F172A"
  on-surface-variant: "#475569"
  outline: "#CBD5E1"
  outline-variant: "#E2E8F0"

  success: "#15803D"
  on-success: "#FFFFFF"
  success-container: "#DCFCE7"
  on-success-container: "#14532D"

  warning: "#B45309"
  on-warning: "#FFFFFF"
  warning-container: "#FEF3C7"
  on-warning-container: "#78350F"

  error: "#B91C1C"
  on-error: "#FFFFFF"
  error-container: "#FEE2E2"
  on-error-container: "#7F1D1D"

typography:
  headline-display:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: 700
    lineHeight: 44px
    letterSpacing: -0.02em

  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: 700
    lineHeight: 36px
    letterSpacing: -0.015em

  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: 600
    lineHeight: 28px

  title-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 600
    lineHeight: 24px

  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 400
    lineHeight: 28px

  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 400
    lineHeight: 24px

  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 400
    lineHeight: 20px

  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 600
    lineHeight: 20px

  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: 600
    lineHeight: 16px
    letterSpacing: 0.01em

rounded:
  none: 0px
  sm: 4px
  md: 8px
  lg: 12px
  xl: 16px
  full: 9999px

spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  page-gutter: 24px
  card-padding: 20px
  section-gap: 32px
  table-row: 12px

components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: 12px

  button-primary-hover:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"

  button-secondary:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.on-secondary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: 12px

  button-secondary-hover:
    backgroundColor: "{colors.secondary-container}"
    textColor: "{colors.on-secondary-container}"

  button-danger:
    backgroundColor: "{colors.error}"
    textColor: "{colors.on-error}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: 12px

  input-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: 12px

  input-field-error:
    backgroundColor: "{colors.error-container}"
    textColor: "{colors.on-error-container}"
    rounded: "{rounded.md}"
    padding: 12px

  card-summary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"

  card-budget:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"

  card-income:
    backgroundColor: "{colors.success-container}"
    textColor: "{colors.on-success-container}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"

  card-expense:
    backgroundColor: "{colors.error-container}"
    textColor: "{colors.on-error-container}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"

  transaction-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: "{spacing.table-row}"

  transaction-row-hover:
    backgroundColor: "{colors.surface-muted}"

  category-chip:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.on-surface-variant}"
    rounded: "{rounded.full}"
    padding: 8px

  success-badge:
    backgroundColor: "{colors.success-container}"
    textColor: "{colors.on-success-container}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.full}"
    padding: 8px

  warning-badge:
    backgroundColor: "{colors.warning-container}"
    textColor: "{colors.on-warning-container}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.full}"
    padding: 8px

  error-badge:
    backgroundColor: "{colors.error-container}"
    textColor: "{colors.on-error-container}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.full}"
    padding: 8px

  chart-tooltip:
    backgroundColor: "{colors.on-surface}"
    textColor: "{colors.neutral}"
    rounded: "{rounded.md}"
    padding: 12px
---

## Overview

Expense Tracker is a calm and trustworthy personal finance product. It helps people record daily expenses, understand where their money goes, monitor monthly budgets, and make better financial decisions without feeling overwhelmed.

The visual language is **Clear Financial Calm**: structured enough for financial data, but friendly enough for everyday use. The interface should feel reliable, transparent, and non-judgmental.

Users should be able to answer these questions immediately:

- How much money did I spend this month?
- Which categories consume the most money?
- Am I close to exceeding my budget?
- What was my most recent transaction?
- What action should I take next?

The design should prioritize comprehension over decoration. Data visualization, totals, trends, and warnings must be more prominent than branding or visual effects.

## Colors

The palette uses blue as the primary action color because it communicates clarity and trust. Teal supports positive financial progress and healthy budget status. Violet is reserved for secondary insights and analytical features.

- **Primary:** `#2563EB` is used for the most important action on a page, such as adding an expense or saving a budget.
- **Secondary:** `#0F766E` is used for positive financial actions, income, savings, and secondary navigation.
- **Tertiary:** `#7C3AED` is used for analytical features, charts, reports, and selected filters.
- **Neutral:** Soft slate and white surfaces provide a calm foundation for tables, forms, and dashboards.
- **Success:** Green indicates income, savings, completed goals, and healthy budget progress.
- **Warning:** Amber indicates that spending is approaching a budget limit.
- **Error:** Red is reserved for failed actions, destructive actions, invalid inputs, and overspending.
- **Surface:** Cards and data regions use white surfaces against a very light slate background.

Do not use color as the only way to communicate financial status. Pair status colors with text, icons, labels, or progress indicators.

## Typography

The interface uses **Inter** because it is highly legible for numbers, tables, form labels, and dashboard metrics.

- **Display numbers:** Use `headline-display` for the main balance, monthly spending total, or budget total.
- **Page headings:** Use `headline-lg` for screen titles such as “Overview”, “Transactions”, and “Budgets”.
- **Section headings:** Use `headline-md` or `title-lg` for groups such as “Recent transactions” and “Spending by category”.
- **Body text:** Use `body-md` for descriptions, explanatory messages, and transaction details.
- **Small metadata:** Use `body-sm` for dates, account names, notes, and supporting information.
- **Labels:** Use `label-md` for buttons, form labels, tabs, and important controls.
- **Statuses:** Use `label-sm` for badges and compact status indicators.

Financial numbers should use tabular numerals when supported. Currency values should remain easy to scan and should not be presented in excessively decorative type.

Use bold weight to establish hierarchy, not to make every data point compete for attention.

## Layout

The layout follows a responsive dashboard model.

- On desktop, use a centered content area with a maximum width of approximately `1200px`.
- On mobile, use a single-column layout with a page gutter of `24px`.
- Use a 4px base unit for micro-spacing and an 8px rhythm for most component spacing.
- Summary cards may use a responsive grid:
  - 1 column on small screens
  - 2 columns on medium screens
  - 4 columns on wide screens
- Keep the primary action, such as “Add expense”, visible without requiring the user to search for it.
- Place the most important financial summary near the top of the page.
- Group related data into clear regions: overview, budget status, charts, and transactions.
- Tables must remain readable on small screens. Prefer responsive cards or horizontal scrolling over compressed unreadable columns.
- Use whitespace to separate financial concepts. Do not fill every empty area with decoration.
- Charts should have clear legends, readable labels, and a text alternative when possible.

## Elevation & Depth

Depth should be subtle and functional.

- Use the page background to separate the application shell from white content cards.
- Use cards to group related information, not to decorate every individual element.
- Avoid heavy shadows, glassmorphism, gradients, and excessive blur.
- Use a soft shadow only when a card must appear above the page, such as a modal, dropdown, or floating action.
- Modals and menus should have stronger elevation than ordinary dashboard cards.
- Charts and tables should usually remain flat inside their parent card.
- Hover and focus states should be visible but restrained.
- A selected card or active filter may use a border or tinted surface rather than a large shadow.

## Shapes

The shape language is **Soft Utility**.

- Use `sm` for compact controls and dense data elements.
- Use `md` for buttons, inputs, transaction rows, and standard interactive controls.
- Use `lg` for summary cards and dashboard containers.
- Use `xl` only for prominent feature panels or empty states.
- Use `full` for category chips, status badges, avatars, and compact filter pills.
- Avoid mixing highly rounded cards with sharp-cornered controls in the same visual group.
- Avoid excessive pill-shaped controls; reserve them for tags, filters, and statuses.

## Components

### Dashboard Summary Cards

Summary cards display the most important financial metrics: current balance, monthly income, monthly expenses, and remaining budget.

Each card should contain:

1. A short label.
2. A prominent value.
3. Optional comparison with the previous period.
4. Optional supporting context such as a progress indicator or date range.

The main value should be visually dominant, but the card must not use oversized typography that pushes supporting information below the fold.

### Add Expense Form

The add-expense form is a primary workflow.

- Keep the number of fields small and understandable.
- Make amount, date, category, and account easy to identify.
- Show validation errors beside the relevant field.
- Preserve entered values when validation fails.
- Use the primary button for saving the expense.
- Use the danger style only for destructive actions such as deleting a transaction.
- Never hide important validation feedback in a toast alone.

### Transaction List

Transactions should be easy to scan chronologically.

Each transaction row may include:

- Category icon or category label.
- Merchant or description.
- Date.
- Account or payment method.
- Amount.
- Optional status.

Expenses and income should be distinguishable by text and amount formatting, not color alone. Use hover states only to clarify the row that is currently interactive.

### Budget Progress

Budget progress should communicate status immediately.

- Green indicates that spending is comfortably within the budget.
- Amber indicates that spending is approaching the limit.
- Red indicates that the budget has been exceeded.
- Always show the numeric values in addition to the progress bar.
- The progress bar must have an accessible text label.

### Charts and Reports

Charts are explanatory tools, not decoration.

- Prefer simple bar charts, line charts, and donut charts with clear labels.
- Use tertiary violet for analytical emphasis, not for every data series.
- Do not rely on color alone to distinguish chart categories.
- Provide tooltips or labels for exact values.
- Use consistent category colors between charts, filters, and transaction lists.

### Empty States

Empty states should be encouraging and actionable.

For example, when there are no transactions:

- Explain what is empty.
- Briefly explain the benefit of adding the first expense.
- Provide a clear “Add expense” action.
- Do not use guilt-inducing language.

### Notifications and Feedback

Success, warning, and error messages should be concise and specific.

- Success feedback confirms what happened.
- Warning feedback explains what requires attention.
- Error feedback explains how to recover.
- Avoid vague messages such as “Something went wrong” when more information is available.

## Do's and Don'ts

- Do make the current balance and monthly spending visible quickly.
- Do use one clear primary action per screen.
- Do show currency, date, and category information consistently.
- Do provide text labels alongside financial status colors.
- Do use accessible contrast for normal text and interactive controls.
- Do support keyboard focus states and screen readers.
- Do preserve form input when validation fails.
- Do use realistic financial examples in previews and demos.
- Do make charts understandable without requiring visual color recognition.

- Don't use red for ordinary expenses; reserve it for overspending, errors, and destructive actions.
- Don't show fake precision in financial amounts.
- Don't overload the dashboard with too many charts.
- Don't use gradients or decorative glass effects for primary financial data.
- Don't hide important actions inside icon-only controls.
- Don't make users guess whether a number is income, expense, balance, or budget.
- Don't use color as the only indicator of success or failure.
- Don't display sensitive account information unnecessarily.
- Don't make the interface feel judgmental about spending behavior.
