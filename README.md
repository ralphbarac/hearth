# Hearth

A self-hosted household management app for families. Hearth brings calendar, budget, grocery lists, inventory, recipes, and more together in one place — private, on your own server.

## Features

- **Calendar** — Shared household calendar with recurring events and per-member visibility
- **Budget** — Transaction tracking, categories, monthly summaries, and saving goals
- **Bills** — Subscription and bill tracking with automatic due-date advancement and optional auto-transaction creation
- **Grocery** — Collaborative shopping lists with real-time sync across devices
- **Inventory** — Track household supplies and pantry stock levels with low-stock alerts
- **Recipes** — Store recipes with ingredients and steps; push ingredients directly to a grocery list
- **Meal Planner** — Wizard that selects recipes, reviews ingredients (checking inventory), and generates a grocery list and calendar events in one flow
- **Chores** — Household chore tracking with completion history
- **Maintenance** — Home maintenance log with recurring service records
- **Contacts** — Household contact book
- **Documents** — Document storage and reference
- **Links** — Cross-feature connections (e.g. link a recipe to a calendar event, a bill to a transaction, or inventory items to grocery lists)

## Architecture

Hearth is an Elixir umbrella project with compiler-enforced boundaries between features:

```
hearth_umbrella/
├── apps/
│   ├── hearth              # Core: auth, users, households, shared Repo, Links
│   ├── hearth_calendar     # Calendar schemas + context (depends on hearth)
│   ├── hearth_budget       # Budget schemas + context (depends on hearth)
│   ├── hearth_grocery      # Grocery schemas + context (depends on hearth)
│   ├── hearth_inventory    # Inventory schemas + context (depends on hearth)
│   ├── hearth_recipes      # Recipe schemas + context (depends on hearth)
│   ├── hearth_chores       # Chores schemas + context (depends on hearth)
│   ├── hearth_maintenance  # Maintenance schemas + context (depends on hearth)
│   ├── hearth_contacts     # Contacts schemas + context (depends on hearth)
│   ├── hearth_documents    # Documents schemas + context (depends on hearth)
│   └── hearth_web          # Phoenix web layer (depends on all above)
└── config/
```

Feature apps **never depend on each other**. Cross-feature coordination goes through `Hearth.Links` in the core app or is assembled in the web layer.

A single shared PostgreSQL database is managed by the `hearth` core app. All migrations live in `apps/hearth/priv/repo/migrations/`.

## Prerequisites

- Elixir 1.18+ / Erlang 27+
- PostgreSQL 14+
- Node.js 18+ (for asset compilation)

## Quickstart

```bash
git clone <repo-url> hearth_umbrella
cd hearth_umbrella

mix deps.get
mix ecto.create
mix ecto.migrate
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000) and complete the first-run setup to create your household and admin account.

## Common Dev Commands

| Command | Description |
|---------|-------------|
| `mix deps.get` | Fetch dependencies |
| `mix compile` | Compile all apps |
| `mix ecto.create` | Create database |
| `mix ecto.migrate` | Run migrations |
| `mix ecto.reset` | Drop + create + migrate |
| `mix test` | Run all tests |
| `mix format` | Format code |
| `mix phx.server` | Start dev server |

## Configuration

Configuration is read from environment variables at runtime (see `config/runtime.exs`):

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes (prod) | PostgreSQL connection string, e.g. `ecto://user:pass@host/db` |
| `SECRET_KEY_BASE` | Yes (prod) | Cookie signing key — generate with `mix phx.gen.secret` |
| `PORT` | No | HTTP port (default `4000`) |
| `POOL_SIZE` | No | DB connection pool size (default `10`) |
| `ECTO_IPV6` | No | Set to `true` to enable IPv6 DB connections |

## Self-Hosted Deployment

Hearth is designed to run as a single server for one family. The recommended deployment path is Elixir releases:

```bash
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
```

Set `DATABASE_URL` and `SECRET_KEY_BASE` in your environment, then run:

```bash
_build/prod/rel/hearth_umbrella/bin/hearth_umbrella start
```

See `mix help release` and the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html) for full details.
