defmodule HearthWeb.HomeLive do
  use HearthWeb, :live_view

  alias HearthCalendar.Events
  alias HearthBudget.{Transactions, Bills}
  alias HearthGrocery.{GroceryLists, GroceryItems}
  alias HearthInventory.InventoryItems
  alias HearthBudget.SavingGoals
  alias HearthDocuments.Documents
  alias HearthChores.Chores
  alias HearthMaintenance.MaintenanceItems
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if connected?(socket) do
      if Accounts.feature_enabled?(scope, "calendar"), do: Events.subscribe(scope)

      if Accounts.feature_enabled?(scope, "budget") do
        Transactions.subscribe(scope)
        Bills.subscribe(scope)
      end

      if Accounts.feature_enabled?(scope, "grocery"), do: GroceryLists.subscribe(scope)
      if Accounts.feature_enabled?(scope, "inventory"), do: InventoryItems.subscribe(scope)
      if Accounts.feature_enabled?(scope, "documents"), do: Documents.subscribe(scope)
      if Accounts.feature_enabled?(scope, "chores"), do: Chores.subscribe(scope)
      if Accounts.feature_enabled?(scope, "maintenance"), do: MaintenanceItems.subscribe(scope)
    end

    {:ok,
     socket |> assign(page_title: "Dashboard", active_nav: :dashboard) |> load_dashboard_data()}
  end

  @impl true
  def handle_info({Events, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}
  def handle_info({Transactions, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}
  def handle_info({Bills, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}
  def handle_info({GroceryLists, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}
  def handle_info({GroceryItems, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}

  def handle_info({InventoryItems, _action, _}, socket),
    do: {:noreply, load_dashboard_data(socket)}

  def handle_info({SavingGoals, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}
  def handle_info({Documents, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}
  def handle_info({Chores, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}
  def handle_info({MaintenanceItems, _action, _}, socket), do: {:noreply, load_dashboard_data(socket)}

  defp load_dashboard_data(socket) do
    scope = socket.assigns.current_scope
    today = Date.utc_today()

    upcoming =
      if Accounts.feature_enabled?(scope, "calendar"),
        do: Events.list_upcoming_events(scope, 5),
        else: []

    summary =
      if Accounts.feature_enabled?(scope, "budget"),
        do: Transactions.monthly_summary(scope, {today.year, today.month}),
        else: nil

    bills_due_soon =
      if Accounts.feature_enabled?(scope, "budget"),
        do: Bills.list_bills_due_soon(scope, 7),
        else: []

    grocery_lists =
      if Accounts.feature_enabled?(scope, "grocery") do
        GroceryLists.list_grocery_lists(scope)
        |> Enum.map(fn list ->
          items = GroceryItems.list_items(scope, list)
          Map.put(list, :unchecked_count, Enum.count(items, &(!&1.checked)))
        end)
      else
        []
      end

    low_stock_items =
      if Accounts.feature_enabled?(scope, "inventory"),
        do: InventoryItems.list_low_stock_items(scope),
        else: []

    active_goals =
      if Accounts.feature_enabled?(scope, "budget"),
        do: SavingGoals.list_goals(scope) |> Enum.reject(& &1.is_complete),
        else: []

    expiring_docs =
      if Accounts.feature_enabled?(scope, "documents"),
        do: Documents.list_expiring_soon(scope),
        else: []

    due_chores =
      if Accounts.feature_enabled?(scope, "chores"),
        do: Chores.list_chores_due_soon(scope),
        else: []

    maintenance_due_soon =
      if Accounts.feature_enabled?(scope, "maintenance"),
        do: MaintenanceItems.list_items_due_soon(scope),
        else: []

    assign(socket,
      upcoming_events: upcoming,
      budget_summary: summary,
      bills_due_soon: bills_due_soon,
      current_month: today,
      grocery_lists: grocery_lists,
      low_stock_items: low_stock_items,
      active_goals: active_goals,
      expiring_docs: expiring_docs,
      due_chores: due_chores,
      maintenance_due_soon: maintenance_due_soon
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <div class="bg-gradient-to-r from-primary/8 to-warning/8 rounded-2xl p-6 mb-6">
        <h1 class="text-2xl font-bold text-base-content">
          Good to see you, <span class="text-primary">{@current_scope.user.username}</span>
        </h1>
        <p class="text-base-content/60 mt-1">{@current_scope.household.name}</p>
      </div>

      <div :if={
        !Accounts.feature_enabled?(@current_scope, "calendar") and
          !Accounts.feature_enabled?(@current_scope, "budget") and
          !Accounts.feature_enabled?(@current_scope, "grocery") and
          !Accounts.feature_enabled?(@current_scope, "inventory") and
          !Accounts.feature_enabled?(@current_scope, "recipes") and
          !Accounts.feature_enabled?(@current_scope, "chores") and
          !Accounts.feature_enabled?(@current_scope, "maintenance") and
          !Accounts.feature_enabled?(@current_scope, "contacts") and
          !Accounts.feature_enabled?(@current_scope, "documents")
      }>
        <div class="alert">
          <.icon name="hero-home" class="size-5" />
          <div>
            <p class="font-medium">Your home is ready — add some features to get started.</p>
            <p class="text-sm">
              Ask an admin to enable features in <.link navigate={~p"/admin/features"} class="link">Feature Settings</.link>.
            </p>
          </div>
        </div>
      </div>

      <div class="mt-6 grid gap-4 md:grid-cols-2">
        <%!-- Upcoming Events Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "calendar")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-calendar-days" class="size-5 text-info" /> Upcoming Events
            </h2>
            <div :if={@upcoming_events == []} class="text-secondary text-sm">
              No upcoming events. Add your first one!
            </div>
            <ul :if={@upcoming_events != []} class="space-y-2">
              <li :for={event <- @upcoming_events} class="flex items-start gap-2 text-sm">
                <span class="text-secondary shrink-0 tabular-nums">
                  {Calendar.strftime(event.starts_at, "%b %d")}
                </span>
                <span class="font-medium truncate">{event.title}</span>
              </li>
            </ul>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/calendar"} class="btn btn-ghost btn-sm text-primary">
                View Calendar &rarr;
              </.link>
            </div>
          </div>
        </div>

        <%!-- Budget Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "budget")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-banknotes" class="size-5 text-primary" /> Budget This Month
            </h2>
            <p class="text-xs text-secondary">
              {Calendar.strftime(Date.new!(@current_month.year, @current_month.month, 1), "%B %Y")}
            </p>
            <div :if={@budget_summary} class="grid grid-cols-3 gap-2 mt-1 text-sm">
              <div>
                <p class="text-secondary text-xs">Income</p>
                <p class="text-2xl font-bold text-success">{format_amount(@budget_summary.income)}</p>
              </div>
              <div>
                <p class="text-secondary text-xs">Expenses</p>
                <p class="text-2xl font-bold text-error">{format_amount(@budget_summary.expenses)}</p>
              </div>
              <div>
                <p class="text-secondary text-xs">Net</p>
                <p class={[
                  "text-2xl font-bold",
                  if(@budget_summary.net >= 0, do: "text-success", else: "text-error")
                ]}>
                  {format_amount(@budget_summary.net)}
                </p>
              </div>
            </div>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/budget"} class="btn btn-ghost btn-sm text-primary">
                View Budget &rarr;
              </.link>
            </div>
          </div>
        </div>

        <%!-- Bills Due Soon Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "budget")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-document-text" class="size-5 text-warning" /> Bills Due Soon
            </h2>
            <div :if={@bills_due_soon == []} class="text-secondary text-sm">
              No bills due in the next 7 days.
            </div>
            <ul :if={@bills_due_soon != []} class="space-y-2">
              <li :for={bill <- @bills_due_soon} class="flex items-center justify-between text-sm">
                <span class="font-medium truncate">{bill.name}</span>
                <div class="flex items-center gap-2 shrink-0 ml-2">
                  <span class="font-semibold">{format_amount(bill.amount)}</span>
                  <span class="text-secondary">{Date.to_string(bill.next_due_date)}</span>
                </div>
              </li>
            </ul>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/bills"} class="btn btn-ghost btn-sm text-primary">
                View Bills &rarr;
              </.link>
            </div>
          </div>
        </div>

        <%!-- Grocery Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "grocery")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200 md:col-span-2"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-shopping-cart" class="size-5 text-accent" /> Grocery Lists
            </h2>
            <div :if={@grocery_lists == []} class="text-secondary text-sm">
              No lists yet. Create your first one!
            </div>
            <ul :if={@grocery_lists != []} class="grid gap-2 sm:grid-cols-2">
              <li
                :for={list <- @grocery_lists}
                class="flex items-center justify-between text-sm p-2 bg-base-200 rounded-lg"
              >
                <span class="font-medium">{list.name}</span>
                <span class="badge badge-ghost">
                  {list.unchecked_count} item{if list.unchecked_count != 1, do: "s"}
                </span>
              </li>
            </ul>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/grocery"} class="btn btn-ghost btn-sm text-primary">
                View Lists &rarr;
              </.link>
            </div>
          </div>
        </div>
        <%!-- Inventory Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "inventory")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-archive-box" class="size-5 text-secondary" /> Inventory
            </h2>
            <div :if={@low_stock_items == []} class="text-secondary text-sm">
              All items well stocked.
            </div>
            <div :if={@low_stock_items != []} class="text-sm">
              <p class="text-warning font-medium">
                {length(@low_stock_items)} item{if length(@low_stock_items) != 1, do: "s"} running low
              </p>
              <ul class="mt-2 space-y-1">
                <li
                  :for={item <- Enum.take(@low_stock_items, 3)}
                  class="text-base-content/70 truncate"
                >
                  {item.name} ({item.quantity}/{item.min_quantity})
                </li>
              </ul>
            </div>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/inventory"} class="btn btn-ghost btn-sm text-primary">
                View Inventory &rarr;
              </.link>
            </div>
          </div>
        </div>
        <%!-- Saving Goals Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "budget")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-trophy" class="size-5 text-success" /> Saving Goals
            </h2>
            <div :if={@active_goals == []} class="text-secondary text-sm">
              No active saving goals.
            </div>
            <ul :if={@active_goals != []} class="space-y-3">
              <li :for={goal <- Enum.take(@active_goals, 3)}>
                <%
                  pct = if goal.target_amount > 0,
                    do: min(round(goal.current_amount / goal.target_amount * 100), 100),
                    else: 0
                %>
                <div class="flex items-center justify-between text-sm mb-1">
                  <span class="font-medium truncate">{goal.name}</span>
                  <span class="text-secondary shrink-0 ml-2 tabular-nums">
                    {format_amount(goal.current_amount)} / {format_amount(goal.target_amount)}
                  </span>
                </div>
                <progress
                  class={["progress w-full", if(pct >= 100, do: "progress-success", else: "progress-primary")]}
                  value={pct}
                  max="100"
                >
                </progress>
              </li>
            </ul>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/budget/goals"} class="btn btn-ghost btn-sm text-primary">
                View Goals &rarr;
              </.link>
            </div>
          </div>
        </div>

        <%!-- Chores Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "chores")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-check-circle" class="size-5 text-success" /> Chores
            </h2>
            <div :if={@due_chores == []} class="text-secondary text-sm">
              No chores due soon.
            </div>
            <div :if={@due_chores != []}>
              <p class="text-warning font-medium text-sm">
                {length(@due_chores)} chore{if length(@due_chores) != 1, do: "s"} due or overdue
              </p>
              <ul class="mt-2 space-y-1">
                <li
                  :for={chore <- Enum.take(@due_chores, 3)}
                  class="text-sm text-base-content/70 truncate"
                >
                  {chore.name} &mdash; {Date.to_string(chore.next_due_date)}
                </li>
              </ul>
            </div>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/chores"} class="btn btn-ghost btn-sm text-primary">
                View Chores &rarr;
              </.link>
            </div>
          </div>
        </div>

        <%!-- Maintenance Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "maintenance")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-wrench-screwdriver" class="size-5 text-warning" /> Maintenance
            </h2>
            <div :if={@maintenance_due_soon == []} class="text-secondary text-sm">
              No maintenance due in the next 30 days.
            </div>
            <div :if={@maintenance_due_soon != []}>
              <p class="text-warning font-medium text-sm">
                {length(@maintenance_due_soon)} item{if length(@maintenance_due_soon) != 1, do: "s"} due soon
              </p>
              <ul class="mt-2 space-y-1">
                <li
                  :for={item <- Enum.take(@maintenance_due_soon, 3)}
                  class="text-sm text-base-content/70 truncate"
                >
                  {item.name} &mdash; {Date.to_string(item.next_due_date)}
                </li>
              </ul>
            </div>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/maintenance"} class="btn btn-ghost btn-sm text-primary">
                View Maintenance &rarr;
              </.link>
            </div>
          </div>
        </div>

        <%!-- Documents Widget --%>
        <div
          :if={Accounts.feature_enabled?(@current_scope, "documents")}
          class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow duration-200"
        >
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-folder" class="size-5 text-secondary" /> Documents
            </h2>
            <div :if={@expiring_docs == []} class="text-secondary text-sm">
              No documents expiring soon.
            </div>
            <div :if={@expiring_docs != []}>
              <p class="text-warning font-medium text-sm">
                {length(@expiring_docs)} document{if length(@expiring_docs) != 1, do: "s"} expiring soon
              </p>
              <ul class="mt-2 space-y-1">
                <li
                  :for={doc <- Enum.take(@expiring_docs, 3)}
                  class="text-sm text-base-content/70 truncate"
                >
                  {doc.name}
                  <%= if doc.expiry_date do %>
                    &mdash; {Date.to_string(doc.expiry_date)}
                  <% end %>
                </li>
              </ul>
            </div>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/documents"} class="btn btn-ghost btn-sm text-primary">
                View Documents &rarr;
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
