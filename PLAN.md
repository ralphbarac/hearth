# Hearth - Self-Hosted Home Management App

## Context

The user wants a privacy-first, self-hosted application to manage household tasks (calendars, budgets, grocery lists) instead of relying on cloud services that harvest data. It will run on a local home server. The project uses an Elixir umbrella architecture so each feature domain has compiler-enforced boundaries while still deploying as a single release on the BEAM.

## Architecture

**Umbrella project** with these apps:

```
hearth_umbrella/
  apps/
    hearth/            # Core: auth, users, households, cross-feature links, shared Repo
    hearth_calendar/   # Calendar feature (schemas + context only)
    hearth_budget/     # Budget feature (schemas + context only)
    hearth_grocery/    # Grocery feature (schemas + context only)
    hearth_web/        # Phoenix web layer (LiveView, router, components)
```

**Dependency direction** (no circular deps):
```
hearth_web --> hearth_calendar, hearth_budget, hearth_grocery, hearth
hearth_calendar --> hearth
hearth_budget   --> hearth
hearth_grocery  --> hearth
```

**Single shared Repo** in `hearth` core app. All migrations live in `apps/hearth/priv/repo/migrations/`.

**Cross-feature linking**: A generic `Hearth.Links` context in core provides a polymorphic `links` table (`source_type/id` <-> `target_type/id`). Feature apps never import each other - the web layer assembles cross-feature UI.

**Household scoping**: Every query is scoped via `Hearth.Accounts.Scope` which carries both `user` and `household`. All context functions accept a scope and filter by `household_id`.

## Tech Stack

- Elixir 1.18.4 (OTP-26), Phoenix 1.8.3, LiveView ~> 1.1
- PostgreSQL, binary UUID primary keys, `utc_datetime` timestamps
- Tailwind + daisyUI, Heroicons
- bcrypt for passwords, standard Phoenix session auth
- Bandit web server, PubSub for real-time updates

## Database Schemas

### Core (`hearth`)

**households**: `id`, `name`, `created_by_id` (ref users), timestamps
**users**: `id`, `email` (citext, unique), `username` (unique), `hashed_password`, `role` (admin|adult|child), `household_id` (ref households), `confirmed_at`, timestamps
**users_tokens**: standard Phoenix auth tokens
**links**: `id`, `household_id`, `source_type`, `source_id`, `target_type`, `target_id`, `metadata` (map), `created_by_id`, timestamps. Unique index on `[source_type, source_id, target_type, target_id]`

### Calendar (`hearth_calendar`)

**calendar_events**: `id`, `household_id`, `title`, `description`, `starts_at`, `ends_at`, `all_day` (bool), `color`, `location`, `created_by_id`, `recurrence_rule` (iCal RRULE string, nullable), timestamps
**visibility_groups**: `id`, `household_id`, `name`, `color`, `is_default` (bool), timestamps
**event_visibility_groups**: `event_id`, `group_id` (join table)
**visibility_group_members**: `group_id`, `user_id` (join table)

### Budget (`hearth_budget`)

**budget_categories**: `id`, `household_id`, `name`, `icon`, `type` (income|expense), `is_default`, timestamps
**budget_transactions**: `id`, `household_id`, `category_id`, `amount` (integer, cents), `type` (income|expense), `description`, `date`, `created_by_id`, timestamps

### Grocery (`hearth_grocery`)

**grocery_lists**: `id`, `household_id`, `name`, `notes`, `is_active` (bool), `created_by_id`, timestamps
**grocery_items**: `id`, `list_id`, `name`, `quantity` (string), `category`, `checked` (bool), `position` (int), `added_by_id`, timestamps

## UI/UX Design

### Color Palette (daisyUI custom theme "hearth")
- Primary: Warm amber (#b45309)
- Background: Warm white (#faf7f2)
- Surface: Cream (#fef3c7 / #f5f0e8)
- Text: Warm charcoal (#292524)
- Success: Sage green (#65a30d)
- Error: Terracotta (#dc2626)
- Info: Soft blue (#3b82f6)

### Design Principles
- Mobile-first, warm & cozy aesthetic
- Light theme only for V1
- Collapsible left sidebar
- Minimal JS - prefer LiveView for interactivity
- System font stack

## Implementation Steps

### Step 0: Project Scaffolding [DONE]
### Step 1: Dev Tooling (CLAUDE.md + claude hex)
### Step 2: Core Auth - Users, Households, Scope
### Step 3: Admin User Management
### Step 4: Navigation Shell + Dashboard
### Step 5: Calendar Feature
### Step 6: Budget Feature
### Step 7: Grocery Feature
### Step 8: Cross-Feature Linking
### Step 9: Dashboard Wiring
### Step 10: Polish + Deployment Prep

## Key Patterns

- **Scope**: `Hearth.Accounts.Scope` struct with `user` + `household` fields; passed to all context functions
- **Schemas**: `@primary_key {:id, :binary_id, autogenerate: true}`, `@foreign_key_type :binary_id`, `timestamps(type: :utc_datetime)`
- **Contexts**: household-scoped queries, Ecto changesets for validation, PubSub broadcasts on mutations
- **LiveViews**: function components for UI, `on_mount` for auth, `handle_info` for PubSub, LiveView Streams for lists
- **Minimal JS**: Use LiveView assigns for sidebar state, server-rendered interactions over JS hooks
