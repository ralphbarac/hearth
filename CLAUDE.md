# Hearth - Development Guide

Hearth is a privacy-first, self-hosted household management app. It is an Elixir umbrella project backed by a single PostgreSQL database, designed for one household per installation. Features include a shared calendar, budget tracker, grocery lists, inventory, and recipe/meal planning.

---

## Build & Test Commands

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

---

## Architecture

Seven apps with compiler-enforced dependency boundaries:

| App | Purpose |
|-----|---------|
| `hearth` | Core: auth, users, households, shared Repo, cross-feature Links |
| `hearth_calendar` | Calendar schemas + context |
| `hearth_budget` | Budget schemas + context |
| `hearth_grocery` | Grocery schemas + context |
| `hearth_inventory` | Inventory schemas + context |
| `hearth_recipes` | Recipe + meal plan schemas + context |
| `hearth_web` | Phoenix LiveView web layer |

**Dependency rule:** Feature apps (`hearth_calendar`, `hearth_budget`, `hearth_grocery`, `hearth_inventory`, `hearth_recipes`) depend on `hearth` only. `hearth_web` depends on all apps. Feature apps **never** depend on each other. Cross-feature coordination goes through `Hearth.Links` in core, or is assembled in the web layer.

---

## Database Conventions

- Single shared Repo in `hearth` core app: `Hearth.Repo`
- All migrations live in `apps/hearth/priv/repo/migrations/`
- Binary UUID primary keys, `utc_datetime` timestamps
- PostgreSQL with `citext` extension

**Schema boilerplate:**
```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
timestamps(type: :utc_datetime)
```

---

## Scope Pattern

All context functions receive a `%Hearth.Accounts.Scope{}` struct:

```elixir
scope.user       # %Hearth.Accounts.User{}
scope.household  # %Hearth.Households.Household{}
```

Every query **must** filter by `household_id`. No cross-household data may be returned.

File: `apps/hearth/lib/hearth/accounts/scope.ex`

---

## Context Conventions

**Standard CRUD names** — all accept `scope` as first argument:
- `list_*` — return all records for the household
- `get_*!` — fetch by id, raise if not found or wrong household
- `change_*` — return a changeset
- `create_*` — insert and broadcast
- `update_*` — update and broadcast
- `delete_*` — delete and broadcast

**PubSub helpers:**
```elixir
# Subscribe to a topic
def subscribe(%Scope{} = scope) do
  Phoenix.PubSub.subscribe(Hearth.PubSub, topic(scope))
end

# tap_broadcast/3: passes through {:ok, result}, broadcasts on success only
defp tap_broadcast(result, scope, action) do
  tap(result, fn
    {:ok, struct} -> broadcast(scope, action, struct)
    _ -> :ok
  end)
end

# Broadcast message format
{ContextModule, :created | :updated | :deleted, struct}
```

---

## PubSub Topics

| Feature | Topic |
|---------|-------|
| Calendar | `"household:{household_id}:calendar"` |
| Budget | `"household:{household_id}:budget"` |
| Grocery list items | `"household:{household_id}:grocery:{list_id}"` |
| Inventory | `"household:{household_id}:inventory"` |
| Recipes | `"household:{household_id}:recipes"` |
| Bills | `"household:{household_id}:bills"` |

---

## LiveView Structure

**`mount/3`:**
```elixir
def mount(_params, _session, socket) do
  if connected?(socket), do: Context.subscribe(scope)
  {:ok, socket |> assign(:page_title, "...") |> assign(:items, Context.list_items(scope))}
end
```

**`handle_event` patterns:**
- `"new_*"` — open form with `change_*(scope, %{})`
- `"edit_*"` — open form with existing struct
- `"delete_*"` — delete and re-fetch list
- `"close_form"` — set form-related assigns to nil

**`handle_info` patterns:**
```elixir
# From FormComponent on successful save
def handle_info({FormComponent, :saved, _struct}, socket) do
  {:noreply, socket |> assign(:form_item, nil) |> reload_list()}
end

# From PubSub (other sessions / other users)
def handle_info({Context, _action, _struct}, socket) do
  {:noreply, reload_list(socket)}
end
```

Use regular `@list` assigns (not streams) when `Enum.group_by/2` is needed.

---

## Form Component Pattern

```elixir
# update/2 — initialize form, always action: nil
def update(assigns, socket) do
  changeset = Context.change_item(scope, item)
  {:ok, assign(socket, ..., form: to_form(changeset, action: nil))}
end

# validate — show errors inline
def handle_event("validate", %{"item" => params}, socket) do
  changeset = Context.change_item(scope, item, params)
  {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
end

# save — dispatch on id presence
def handle_event("save", %{"item" => params}, socket) do
  if item.id do
    Context.update_item(scope, item, params)
  else
    Context.create_item(scope, params)
  end
  |> case do
    {:ok, saved} ->
      send(self(), {__MODULE__, :saved, saved})
      {:noreply, socket}
    {:error, changeset} ->
      {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end
end
```

---

## Amount-as-Cents (Budget)

- Store integer cents in the database (`amount :integer`)
- Virtual field in schema: `field :amount_input, :string, virtual: true`
- `convert_amount_input/1` private function:
  ```elixir
  defp convert_amount_input(changeset) do
    case get_change(changeset, :amount_input) do
      nil -> changeset
      input ->
        {float, _} = Float.parse(input)
        put_change(changeset, :amount, round(float * 100))
    end
  end
  ```
- Cast both `amount` (integer, programmatic) and `amount_input` (string, form input); `convert_amount_input` overwrites `amount` when `amount_input` is present
- Pre-populate on edit: `:erlang.float_to_binary(cents / 100, decimals: 2)`
- Display helper:
  ```elixir
  def format_amount(cents) when cents < 0, do: "-$#{format_abs(abs(cents))}"
  def format_amount(cents), do: "$#{format_abs(cents)}"
  defp format_abs(cents) do
    dollars = div(cents, 100)
    cents_str = Integer.to_string(rem(cents, 100))
    "#{dollars}.#{String.pad_leading(cents_str, 2, "0")}"
  end
  ```

---

## Month Navigation (Budget)

- `current_month` assign: `%Date{}` representing the first day of the month — `Date.new!(year, month, 1)`
- Navigate: `Date.shift(current_month, month: -1)` / `Date.shift(current_month, month: +1)`
- Extract for queries: `{current_month.year, current_month.month}`
- Range upper bound: `Date.end_of_month(current_month)`

---

## Recurring Calendar Events

- `recurrence_type` enum: `~w(none daily weekly monthly yearly)` — stored on the series event row
- `recurrence_parent_id` FK on detached occurrences (these have `recurrence_type: "none"`)
- `HearthCalendar.EventException` tracks excluded dates per series event
- `expand_occurrences/3` uses `Stream.iterate` + `take_while` + `Enum.filter`; terminates at `to_date` or configured count/until limit
- `Date.shift/2` monthly/yearly overflow: Jan 31 → Feb 28 → Mar 28 (truncates and stays truncated)
- Virtual occurrence struct: `%{series | id: nil, starts_at: occ_starts, series_id: series.id}`
- `build_occurrence_for_modal/2` in `CalendarLive.Index` resets recurrence fields to `"none"` for detached occurrences
- `recurrence_modal` assign: `%{action: :edit | :delete, series_id:, occurrence_date:}`
- `editing_as_detached` assign: `{series_id, occurrence_date}` or `nil`
- Web chips use `phx-click.stop` (grid) vs plain `phx-click` (day panel); tests interact via day panel after `select_date`

---

## Cross-Feature Links

- `Hearth.Links` context + `Hearth.Links.Link` schema live in `hearth` core
- `source_id` / `target_id` are plain binary UUIDs — no FK constraints (polymorphic)
- Unique constraint named `:links_household_source_target_unique` (custom short name, 63-char PG limit)
- Canonical link direction: `calendar_event → grocery_list`, `calendar_event → budget_transaction`, `calendar_event → recipe`
- Key functions:
  - `toggle_link/5` — creates if not found, deletes if found
  - `get_linked_ids/4` — handles reverse lookup bidirectionally
  - `delete_link/2` — guards with `link.household_id == household.id`
- Only `hearth_web` aliases cross-feature contexts; feature apps never import each other

---

## Feature Flags

Stored as `Household.features` map. Keys:

| Key | Feature |
|-----|---------|
| `"calendar"` | Calendar |
| `"budget"` | Budget |
| `"grocery"` | Grocery lists |
| `"inventory"` | Inventory |
| `"recipes"` | Recipes |

Meal Planner is enabled when **both** `"calendar"` and `"recipes"` are enabled.

---

## UI/UX

- daisyUI **"hearth" theme** (warm amber palette), light only
- Mobile-first layout; sidebar navigation with LiveView-managed state
- Minimal JS — prefer LiveView for all interactivity
- System font stack + Heroicons
- Use `<.form>` and `<.input field={@form[:field]} ...>` directly — **no `simple_form` component**

**Color class strings must be written in full** (Tailwind purge strips dynamic strings):
```elixir
defp color_class("blue"),   do: "bg-info"
defp color_class("green"),  do: "bg-success"
defp color_class("amber"),  do: "bg-warning"
defp color_class("rose"),   do: "bg-error"
defp color_class("purple"), do: "bg-purple-500"
defp color_class("slate"),  do: "bg-slate-400"
```

---

## Test Infrastructure

- Feature app `DataCase` delegates to `Hearth.DataCase.setup_sandbox/1`
- `test_helper.exs` in each feature app must set:
  ```elixir
  Ecto.Adapters.SQL.Sandbox.mode(Hearth.Repo, :manual)
  ```
- `user_scope_fixture/0` is defined in `Hearth.AccountsFixtures` — import it in feature fixture helpers
- Fixture convention: `valid_*_attributes/1` returns a base map; `*_fixture/2` creates and returns a persisted struct

**Key test support files:**
- `apps/hearth/test/support/data_case.ex`
- `apps/hearth/test/support/fixtures/accounts_fixtures.ex`
- `apps/hearth_web/test/support/conn_case.ex`

---

## Known Gotchas

1. **Datetime inputs:** Browsers send 16-char `"YYYY-MM-DDTHH:MM"` (no seconds). Changesets that accept datetime must normalize: if `String.length(value) == 16`, append `":00"` before Ecto casts.

2. **LiveView test select fields:** `render_submit` with a value not in the select options list raises `ArgumentError`. In blank-submit validation tests, omit select fields entirely so they keep their default value.

3. **Tailwind color classes:** Must be written as full strings. Do not build class names dynamically (e.g. `"bg-#{color}-500"`) — Tailwind's scanner won't detect them and the class will be purged.

4. **No `simple_form`:** Phoenix 1.8 with daisyUI generates `<.form>` directly. Always use `<.input field={@form[:field]} ...>` — there is no `<.simple_form>` wrapper.

5. **`Date.shift/2` monthly overflow:** Shifting Jan 31 by 1 month gives Feb 28 (or 29), not an error, and further shifts from Feb 28 stay at month-end (Mar 28, not Mar 31). Account for this in recurrence expansion.

6. **Scope guard in deletes:** Always verify `record.household_id == scope.household.id` before deleting — `get_*!` should enforce this, but double-check in Link deletion which uses raw IDs.
