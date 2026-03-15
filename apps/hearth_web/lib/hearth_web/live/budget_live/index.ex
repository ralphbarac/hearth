defmodule HearthWeb.BudgetLive.Index do
  use HearthWeb, :live_view

  alias HearthBudget.Categories
  alias HearthBudget.Transactions
  alias HearthBudget.Transaction
  alias HearthWeb.BudgetLive.TransactionFormComponent
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "budget") do
      {:ok,
       socket
       |> put_flash(:error, "Budget is not enabled for your account.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: Transactions.subscribe(scope)

      Categories.ensure_defaults(scope)

      today = Date.utc_today()
      year = today.year
      month = today.month

      {:ok,
       socket
       |> assign(page_title: "Budget", active_nav: :budget)
       |> assign(current_month: Date.new!(year, month, 1))
       |> assign(show_form: false)
       |> assign(editing_transaction: nil)
       |> load_month_data(scope, year, month)}
    end
  end

  @impl true
  def handle_event("new_transaction", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_transaction: %Transaction{})}
  end

  def handle_event("edit_transaction", %{"id" => id}, socket) do
    transaction = Transactions.get_transaction!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, editing_transaction: transaction)}
  end

  def handle_event("delete_transaction", %{"id" => id}, socket) do
    transaction = Transactions.get_transaction!(socket.assigns.current_scope, id)
    {:ok, _} = Transactions.delete_transaction(socket.assigns.current_scope, transaction)

    scope = socket.assigns.current_scope
    {year, month} = current_ym(socket)

    {:noreply,
     socket
     |> put_flash(:info, "Transaction deleted.")
     |> load_month_data(scope, year, month)}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_transaction: nil)}
  end

  def handle_event("prev_month", _params, socket) do
    new_date = Date.shift(socket.assigns.current_month, month: -1)
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(current_month: new_date)
     |> load_month_data(scope, new_date.year, new_date.month)}
  end

  def handle_event("next_month", _params, socket) do
    new_date = Date.shift(socket.assigns.current_month, month: 1)
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(current_month: new_date)
     |> load_month_data(scope, new_date.year, new_date.month)}
  end

  @impl true
  def handle_info({TransactionFormComponent, :saved, _transaction}, socket) do
    scope = socket.assigns.current_scope
    {year, month} = current_ym(socket)

    {:noreply,
     socket
     |> assign(show_form: false, editing_transaction: nil)
     |> load_month_data(scope, year, month)}
  end

  def handle_info({Transactions, _action, _transaction}, socket) do
    scope = socket.assigns.current_scope
    {year, month} = current_ym(socket)
    {:noreply, load_month_data(socket, scope, year, month)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Budget
        <:actions>
          <.button phx-click="new_transaction" variant="primary">Add Transaction</.button>
        </:actions>
      </.header>

      <div class="mt-4 flex items-center gap-4">
        <.button
          phx-click="prev_month"
          class="btn btn-ghost btn-sm btn-circle"
          aria-label="Previous month"
        >
          <.icon name="hero-chevron-left" class="size-4" />
        </.button>
        <span class="font-semibold text-lg min-w-32 text-center">
          {Calendar.strftime(@current_month, "%B %Y")}
        </span>
        <.button
          phx-click="next_month"
          class="btn btn-ghost btn-sm btn-circle"
          aria-label="Next month"
        >
          <.icon name="hero-chevron-right" class="size-4" />
        </.button>
      </div>

      <div class="mt-4 grid grid-cols-3 gap-4">
        <div class="card bg-success/10 border border-success/20">
          <div class="card-body p-3">
            <p class="text-xs text-base-content/60 uppercase tracking-wide">Income</p>
            <p class="text-xl font-bold text-success">{format_amount(@summary.income)}</p>
          </div>
        </div>
        <div class="card bg-error/10 border border-error/20">
          <div class="card-body p-3">
            <p class="text-xs text-base-content/60 uppercase tracking-wide">Expenses</p>
            <p class="text-xl font-bold text-error">{format_amount(@summary.expenses)}</p>
          </div>
        </div>
        <div class={["card border", net_card_class(@summary.net)]}>
          <div class="card-body p-3">
            <p class="text-xs text-base-content/60 uppercase tracking-wide">Net</p>
            <p class={["text-xl font-bold", net_text_class(@summary.net)]}>
              {format_amount(@summary.net)}
            </p>
          </div>
        </div>
      </div>

      <div class="mt-6 grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body p-4">
            <h3 class="font-semibold text-sm text-base-content/60 uppercase tracking-wide mb-2">
              Spending by Category
            </h3>
            <canvas
              id="budget-category-chart"
              phx-hook="BudgetChart"
              data-chart-type="category"
              data-chart-data={Jason.encode!(@spending_by_category)}
            />
          </div>
        </div>
        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body p-4">
            <h3 class="font-semibold text-sm text-base-content/60 uppercase tracking-wide mb-2">
              Income vs Expenses (6 months)
            </h3>
            <canvas
              id="budget-monthly-chart"
              phx-hook="BudgetChart"
              data-chart-type="monthly"
              data-chart-data={Jason.encode!(@monthly_summaries)}
            />
          </div>
        </div>
      </div>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form && "hidden md:block"]}>
          <%= if @transactions == [] do %>
            <.empty_state
              icon="hero-banknotes"
              message="No transactions this month. Add one to get started!"
            />
          <% else %>
            <div class="space-y-2">
              <%= for transaction <- @transactions do %>
                <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                  <div class="card-body p-3 flex flex-row items-center gap-3">
                    <div class={["w-2 h-8 rounded-full shrink-0", type_color_class(transaction.type)]}>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="font-medium truncate">
                        {transaction.description || "No description"}
                      </p>
                      <p class="text-sm text-base-content/60">
                        {Date.to_string(transaction.date)}
                        <%= if transaction.category do %>
                          <span class="ml-1">
                            &bull; {transaction.category.name}
                          </span>
                        <% end %>
                      </p>
                    </div>
                    <div class="shrink-0 text-right">
                      <p class={[
                        "font-semibold",
                        if(transaction.type == "income", do: "text-success", else: "text-error")
                      ]}>
                        {if transaction.type == "expense", do: "-"}{format_amount(transaction.amount)}
                      </p>
                    </div>
                    <div class="flex gap-1 shrink-0">
                      <.button
                        phx-click="edit_transaction"
                        phx-value-id={transaction.id}
                        class="btn btn-ghost btn-xs"
                      >
                        Edit
                      </.button>
                      <.button
                        phx-click="delete_transaction"
                        phx-value-id={transaction.id}
                        data-confirm="Delete this transaction?"
                        class="btn btn-ghost btn-xs text-error"
                      >
                        Delete
                      </.button>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div :if={@show_form} class="w-full md:w-96 shrink-0">
          <div class="flex items-center gap-2 mb-4 md:hidden">
            <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Back">
              <.icon name="hero-arrow-left" class="size-4" />
            </.button>
            <span class="font-medium">
              {if @editing_transaction && @editing_transaction.id,
                do: "Edit Transaction",
                else: "New Transaction"}
            </span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">
                  {if @editing_transaction && @editing_transaction.id,
                    do: "Edit Transaction",
                    else: "New Transaction"}
                </h3>
                <.button
                  phx-click="close_form"
                  class="btn btn-ghost btn-sm btn-circle"
                  aria-label="Close"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>
              <.live_component
                module={TransactionFormComponent}
                id={(@editing_transaction && @editing_transaction.id) || "new"}
                transaction={@editing_transaction}
                scope={@current_scope}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_month_data(socket, scope, year, month) do
    transactions = Transactions.list_transactions_for_month(scope, {year, month})
    summary = Transactions.monthly_summary(scope, {year, month})
    spending_by_category = Transactions.spending_by_category(scope, {year, month})
    monthly_summaries = Transactions.monthly_summaries(scope)

    assign(socket,
      transactions: transactions,
      summary: summary,
      spending_by_category: spending_by_category,
      monthly_summaries: monthly_summaries
    )
  end

  defp current_ym(socket) do
    d = socket.assigns.current_month
    {d.year, d.month}
  end

  defp type_color_class("income"), do: "bg-success"
  defp type_color_class("expense"), do: "bg-error"
  defp type_color_class(_), do: "bg-base-300"

  defp net_card_class(net) when net >= 0, do: "bg-success/10 border-success/20"
  defp net_card_class(_), do: "bg-error/10 border-error/20"

  defp net_text_class(net) when net >= 0, do: "text-success"
  defp net_text_class(_), do: "text-error"
end
