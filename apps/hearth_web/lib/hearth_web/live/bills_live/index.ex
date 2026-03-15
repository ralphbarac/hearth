defmodule HearthWeb.BillsLive.Index do
  use HearthWeb, :live_view

  alias HearthBudget.Bills
  alias HearthBudget.Bill
  alias HearthWeb.BillsLive.BillFormComponent
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
      if connected?(socket), do: Bills.subscribe(scope)

      {:ok,
       socket
       |> assign(page_title: "Recurring", active_nav: :bills)
       |> assign(show_form: false)
       |> assign(editing_bill: nil)
       |> load_bills()}
    end
  end

  @impl true
  def handle_event("new_bill", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_bill: %Bill{})}
  end

  def handle_event("edit_bill", %{"id" => id}, socket) do
    bill = Bills.get_bill!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, editing_bill: bill)}
  end

  def handle_event("delete_bill", %{"id" => id}, socket) do
    bill = Bills.get_bill!(socket.assigns.current_scope, id)
    {:ok, _} = Bills.delete_bill(socket.assigns.current_scope, bill)

    {:noreply,
     socket
     |> put_flash(:info, "Bill deleted.")
     |> load_bills()}
  end

  def handle_event("mark_paid", %{"id" => id}, socket) do
    bill = Bills.get_bill!(socket.assigns.current_scope, id)
    {:ok, _} = Bills.mark_paid(socket.assigns.current_scope, bill)

    flash_msg =
      if bill.type == "income",
        do: "Income marked as received.",
        else: "Bill marked as paid. Next due date updated."

    {:noreply,
     socket
     |> put_flash(:info, flash_msg)
     |> load_bills()}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_bill: nil)}
  end

  @impl true
  def handle_info({BillFormComponent, :saved, _bill}, socket) do
    {:noreply,
     socket
     |> assign(show_form: false, editing_bill: nil)
     |> load_bills()}
  end

  def handle_info({Bills, _action, _bill}, socket) do
    {:noreply, load_bills(socket)}
  end

  defp load_bills(socket) do
    scope = socket.assigns.current_scope
    bills = Bills.list_bills(scope)
    {active, inactive} = Enum.split_with(bills, & &1.is_active)
    active_expenses = Enum.filter(active, &(&1.type == "expense"))
    active_income = Enum.filter(active, &(&1.type == "income"))
    assign(socket, active_expenses: active_expenses, active_income: active_income, inactive_bills: inactive)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Recurring
        <:actions>
          <.button phx-click="new_bill" variant="primary">Add Bill</.button>
        </:actions>
      </.header>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form && "hidden md:block"]}>
          <%= if @active_expenses == [] and @active_income == [] do %>
            <.empty_state
              icon="hero-document-text"
              message="No active bills. Add one to get started!"
            />
          <% end %>

          <%= if @active_expenses != [] do %>
            <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3">
              Active Expenses
            </h2>
            <div class="space-y-2 mb-6">
              <%= for bill <- @active_expenses do %>
                <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                  <div class="card-body p-3 flex flex-row items-center gap-3">
                    <div class="flex-1 min-w-0">
                      <p class="font-medium truncate">{bill.name}</p>
                      <p class="text-sm text-base-content/60">
                        {String.capitalize(bill.frequency)} &bull; Due {Date.to_string(
                          bill.next_due_date
                        )}
                        <%= if bill.category do %>
                          <span class="ml-1">&bull; {bill.category.name}</span>
                        <% end %>
                      </p>
                    </div>
                    <div class="shrink-0 text-right">
                      <p class="font-semibold">{format_amount(bill.amount)}</p>
                      <%= if bill.auto_create_transaction do %>
                        <span class="badge badge-ghost badge-xs">auto</span>
                      <% end %>
                    </div>
                    <div class="flex gap-1 shrink-0">
                      <.button
                        phx-click="mark_paid"
                        phx-value-id={bill.id}
                        class="btn btn-ghost btn-xs text-success"
                      >
                        Mark Paid
                      </.button>
                      <.button
                        phx-click="edit_bill"
                        phx-value-id={bill.id}
                        class="btn btn-ghost btn-xs"
                      >
                        Edit
                      </.button>
                      <.button
                        phx-click="delete_bill"
                        phx-value-id={bill.id}
                        data-confirm="Delete this bill?"
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

          <%= if @active_income != [] do %>
            <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3">
              Active Income
            </h2>
            <div class="space-y-2 mb-6">
              <%= for bill <- @active_income do %>
                <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                  <div class="card-body p-3 flex flex-row items-center gap-3">
                    <div class="flex-1 min-w-0">
                      <p class="font-medium truncate">{bill.name}</p>
                      <p class="text-sm text-base-content/60">
                        {String.capitalize(bill.frequency)} &bull; Due {Date.to_string(
                          bill.next_due_date
                        )}
                        <%= if bill.category do %>
                          <span class="ml-1">&bull; {bill.category.name}</span>
                        <% end %>
                      </p>
                    </div>
                    <div class="shrink-0 text-right">
                      <p class="font-semibold">{format_amount(bill.amount)}</p>
                      <%= if bill.auto_create_transaction do %>
                        <span class="badge badge-ghost badge-xs">auto</span>
                      <% end %>
                    </div>
                    <div class="flex gap-1 shrink-0">
                      <.button
                        phx-click="mark_paid"
                        phx-value-id={bill.id}
                        class="btn btn-ghost btn-xs text-success"
                      >
                        Mark Received
                      </.button>
                      <.button
                        phx-click="edit_bill"
                        phx-value-id={bill.id}
                        class="btn btn-ghost btn-xs"
                      >
                        Edit
                      </.button>
                      <.button
                        phx-click="delete_bill"
                        phx-value-id={bill.id}
                        data-confirm="Delete this bill?"
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

          <%= if @inactive_bills != [] do %>
            <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3">
              Inactive Bills
            </h2>
            <div class="space-y-2 opacity-60">
              <%= for bill <- @inactive_bills do %>
                <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                  <div class="card-body p-3 flex flex-row items-center gap-3">
                    <div class="flex-1 min-w-0">
                      <p class="font-medium truncate">{bill.name}</p>
                      <p class="text-sm text-base-content/60">
                        {String.capitalize(bill.frequency)} &bull; Due {Date.to_string(
                          bill.next_due_date
                        )}
                      </p>
                    </div>
                    <div class="shrink-0 text-right">
                      <p class="font-semibold">{format_amount(bill.amount)}</p>
                    </div>
                    <div class="flex gap-1 shrink-0">
                      <.button
                        phx-click="edit_bill"
                        phx-value-id={bill.id}
                        class="btn btn-ghost btn-xs"
                      >
                        Edit
                      </.button>
                      <.button
                        phx-click="delete_bill"
                        phx-value-id={bill.id}
                        data-confirm="Delete this bill?"
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
              {if @editing_bill && @editing_bill.id, do: "Edit Bill", else: "New Bill"}
            </span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">
                  {if @editing_bill && @editing_bill.id, do: "Edit Bill", else: "New Bill"}
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
                module={BillFormComponent}
                id={(@editing_bill && @editing_bill.id) || "new"}
                bill={@editing_bill}
                scope={@current_scope}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
