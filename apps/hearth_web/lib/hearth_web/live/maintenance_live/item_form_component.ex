defmodule HearthWeb.MaintenanceLive.ItemFormComponent do
  use HearthWeb, :live_component

  alias HearthMaintenance.MaintenanceItems

  @impl true
  def update(assigns, socket) do
    item = assigns.item
    changeset = MaintenanceItems.change_item(assigns.scope, item)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(changeset, action: nil))}
  end

  @impl true
  def handle_event("validate", %{"maintenance_item" => params}, socket) do
    changeset = MaintenanceItems.change_item(socket.assigns.scope, socket.assigns.item, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"maintenance_item" => params}, socket) do
    scope = socket.assigns.scope
    item = socket.assigns.item

    result =
      if item.id do
        MaintenanceItems.update_item(scope, item, params)
      else
        MaintenanceItems.create_item(scope, params)
      end

    case result do
      {:ok, saved} ->
        send(self(), {__MODULE__, :saved, saved})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="space-y-4">
          <.input field={@form[:name]} label="Name" placeholder="e.g. HVAC Filter, Car Oil Change" required />
          <.input field={@form[:description]} label="Description" type="textarea" />
          <.input
            field={@form[:category]}
            label="Category"
            placeholder="e.g. HVAC, Vehicle, Appliance"
          />
          <.input
            field={@form[:interval_days]}
            label="Interval (days)"
            type="number"
            min="1"
            required
          />
          <.input field={@form[:next_due_date]} label="Next Due Date" type="date" required />
          <.input field={@form[:notes]} label="Notes" type="textarea" />
          <.input field={@form[:is_active]} label="Active" type="checkbox" />
        </div>
        <div class="flex gap-2 mt-6">
          <.button type="submit" variant="primary" class="flex-1">
            {if @item && @item.id, do: "Save Changes", else: "Add Item"}
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
