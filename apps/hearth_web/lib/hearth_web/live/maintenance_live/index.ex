defmodule HearthWeb.MaintenanceLive.Index do
  use HearthWeb, :live_view

  alias HearthMaintenance.{MaintenanceItems, MaintenanceItem, MaintenanceRecord}
  alias HearthWeb.MaintenanceLive.ItemFormComponent
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "maintenance") do
      {:ok,
       socket
       |> put_flash(:error, "Home Maintenance is not enabled for your household.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: MaintenanceItems.subscribe(scope)

      {:ok,
       socket
       |> assign(page_title: "Home Maintenance", active_nav: :maintenance)
       |> assign(show_form: false, editing_item: nil)
       |> assign(log_modal_item: nil, log_form: nil)
       |> assign(show_history_item_id: nil, history_records: [])
       |> load_items()}
    end
  end

  @impl true
  def handle_event("new_item", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_item: %MaintenanceItem{})}
  end

  def handle_event("edit_item", %{"id" => id}, socket) do
    item = MaintenanceItems.get_item!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, editing_item: item)}
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    item = MaintenanceItems.get_item!(socket.assigns.current_scope, id)
    {:ok, _} = MaintenanceItems.delete_item(socket.assigns.current_scope, item)

    {:noreply,
     socket
     |> put_flash(:info, "Item deleted.")
     |> load_items()}
  end

  def handle_event("show_log_modal", %{"id" => id}, socket) do
    item = MaintenanceItems.get_item!(socket.assigns.current_scope, id)
    today = Date.to_string(Date.utc_today())
    changeset = MaintenanceRecord.changeset(%MaintenanceRecord{}, %{"performed_on" => today})
    log_form = to_form(changeset, action: nil)
    {:noreply, assign(socket, log_modal_item: item, log_form: log_form)}
  end

  def handle_event("close_log_modal", _params, socket) do
    {:noreply, assign(socket, log_modal_item: nil, log_form: nil)}
  end

  def handle_event("validate_log", %{"maintenance_record" => params}, socket) do
    changeset = MaintenanceRecord.changeset(%MaintenanceRecord{}, params)
    {:noreply, assign(socket, log_form: to_form(changeset, action: :validate))}
  end

  def handle_event("save_log", %{"maintenance_record" => params}, socket) do
    scope = socket.assigns.current_scope
    item = socket.assigns.log_modal_item

    case MaintenanceItems.log_maintenance(scope, item, params) do
      {:ok, _updated_item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Maintenance logged!")
         |> assign(log_modal_item: nil, log_form: nil)
         |> load_items()}

      {:error, changeset} ->
        {:noreply, assign(socket, log_form: to_form(changeset, action: :validate))}
    end
  end

  def handle_event("show_history", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    item = MaintenanceItems.get_item!(scope, id)
    records = MaintenanceItems.list_records(scope, item)
    {:noreply, assign(socket, show_history_item_id: id, history_records: records)}
  end

  def handle_event("hide_history", _params, socket) do
    {:noreply, assign(socket, show_history_item_id: nil, history_records: [])}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  @impl true
  def handle_info({ItemFormComponent, :saved, _item}, socket) do
    {:noreply,
     socket
     |> assign(show_form: false, editing_item: nil)
     |> load_items()}
  end

  def handle_info({MaintenanceItems, _action, _item}, socket) do
    {:noreply, load_items(socket)}
  end

  defp load_items(socket) do
    scope = socket.assigns.current_scope
    assign(socket, items: MaintenanceItems.list_items(scope))
  end

  defp days_until(date) do
    Date.diff(date, Date.utc_today())
  end

  defp due_badge_class(days) when days < 0, do: "badge-error"
  defp due_badge_class(days) when days <= 7, do: "badge-warning"
  defp due_badge_class(_days), do: "badge-ghost"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Home Maintenance
        <:actions>
          <.button phx-click="new_item" variant="primary">Add Item</.button>
        </:actions>
      </.header>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form && "hidden md:block"]}>
          <%= if @items == [] do %>
            <.empty_state
              icon="hero-wrench-screwdriver"
              message="No maintenance items yet. Add your first one!"
            />
          <% else %>
            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <%= for item <- @items do %>
                <% days = days_until(item.next_due_date) %>
                <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                  <div class="card-body p-4">
                    <div class="flex items-start justify-between gap-2">
                      <div class="flex-1 min-w-0">
                        <p class="font-semibold truncate">{item.name}</p>
                        <%= if item.category do %>
                          <p class="text-xs text-base-content/60">{item.category}</p>
                        <% end %>
                      </div>
                      <span class={["badge badge-sm", due_badge_class(days)]}>
                        <%= cond do %>
                          <% days < 0 -> %>
                            {abs(days)}d overdue
                          <% days == 0 -> %>
                            Due today
                          <% true -> %>
                            {days}d
                        <% end %>
                      </span>
                    </div>
                    <p class="text-xs text-base-content/50 mt-1">
                      Every {item.interval_days} days &bull; Next: {Date.to_string(item.next_due_date)}
                    </p>

                    <%!-- History panel --%>
                    <%= if @show_history_item_id == item.id do %>
                      <div class="mt-3 border-t border-base-200 pt-3">
                        <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60 mb-2">History</p>
                        <%= if @history_records == [] do %>
                          <p class="text-xs text-base-content/50">No records yet.</p>
                        <% else %>
                          <ul class="space-y-1">
                            <%= for rec <- @history_records do %>
                              <li class="text-xs text-base-content/70">
                                {Date.to_string(rec.performed_on)}
                                <%= if rec.notes do %>
                                  &mdash; {rec.notes}
                                <% end %>
                              </li>
                            <% end %>
                          </ul>
                        <% end %>
                        <button
                          phx-click="hide_history"
                          class="text-xs text-base-content/50 mt-2 hover:underline"
                        >
                          Hide history
                        </button>
                      </div>
                    <% end %>

                    <div class="flex flex-wrap gap-1 mt-3">
                      <.button
                        phx-click="show_log_modal"
                        phx-value-id={item.id}
                        class="btn btn-success btn-xs"
                      >
                        Log
                      </.button>
                      <.button
                        phx-click="show_history"
                        phx-value-id={item.id}
                        class="btn btn-ghost btn-xs"
                      >
                        History
                      </.button>
                      <.button
                        phx-click="edit_item"
                        phx-value-id={item.id}
                        class="btn btn-ghost btn-xs"
                      >
                        Edit
                      </.button>
                      <.button
                        phx-click="delete_item"
                        phx-value-id={item.id}
                        data-confirm="Delete this item?"
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
              {if @editing_item && @editing_item.id, do: "Edit Item", else: "New Item"}
            </span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">
                  {if @editing_item && @editing_item.id, do: "Edit Item", else: "New Item"}
                </h3>
                <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Close">
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>
              <.live_component
                module={ItemFormComponent}
                id={(@editing_item && @editing_item.id) || "new"}
                item={@editing_item}
                scope={@current_scope}
              />
            </div>
          </div>
        </div>
      </div>

      <%!-- Log Maintenance Modal --%>
      <%= if @log_modal_item do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Log Maintenance: {@log_modal_item.name}</h3>
            <.form for={@log_form} phx-change="validate_log" phx-submit="save_log">
              <div class="space-y-4">
                <.input field={@log_form[:performed_on]} label="Date Performed" type="date" required />
                <.input field={@log_form[:notes]} label="Notes" type="textarea" placeholder="What was done?" />
                <.input
                  field={@log_form[:cost_input]}
                  label="Cost (optional)"
                  placeholder="0.00"
                />
              </div>
              <div class="modal-action">
                <.button type="button" phx-click="close_log_modal" class="btn btn-ghost">
                  Cancel
                </.button>
                <.button type="submit" variant="primary">Save Log</.button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="close_log_modal"></div>
        </div>
      <% end %>
    </div>
    """
  end
end
