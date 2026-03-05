# Hearth - Development Guide

## Project Plan
See `PLAN.md` for the full architecture, UI/UX design, database schemas, and implementation roadmap.

## Quick Reference

### Build & Test Commands
```bash
mix deps.get          # Fetch dependencies
mix compile           # Compile all apps
mix ecto.create       # Create database
mix ecto.migrate      # Run migrations
mix ecto.reset        # Drop + create + migrate + seed
mix test              # Run all tests
mix format            # Format code
mix phx.server        # Start dev server
```

### Architecture
Umbrella project with compiler-enforced boundaries:
- `hearth` - Core: auth, users, households, shared Repo, cross-feature links
- `hearth_calendar` - Calendar schemas + context (depends on hearth)
- `hearth_budget` - Budget schemas + context (depends on hearth)
- `hearth_grocery` - Grocery schemas + context (depends on hearth)
- `hearth_web` - Phoenix web layer (depends on all above)

Feature apps NEVER depend on each other. Cross-feature coordination goes through `Hearth.Links` in core or is assembled in the web layer.

### Database
- Single shared Repo in `hearth` core app
- All migrations in `apps/hearth/priv/repo/migrations/`
- Binary UUID primary keys, `utc_datetime` timestamps
- PostgreSQL with citext extension

### Schema Pattern
```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
timestamps(type: :utc_datetime)
```

### Scope Pattern
All context functions receive a `%Hearth.Accounts.Scope{}` struct carrying `user` and `household`. Every query must filter by `household_id`.

### PubSub Topics
- `"household:{household_id}:calendar"` - calendar events
- `"household:{household_id}:budget"` - budget changes
- `"household:{household_id}:grocery:{list_id}"` - grocery list items

### UI/UX
- daisyUI "hearth" theme (warm amber palette)
- Mobile-first, light theme only
- Minimal JS - prefer LiveView for all interactivity
- System font stack, Heroicons
- Sidebar navigation with LiveView-managed state
