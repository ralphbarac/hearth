defmodule HearthWeb.InventoryLive.ItemFormComponent do
  use HearthWeb, :live_component

  alias HearthInventory.InventoryItems
  alias HearthInventory.InventoryItem

  @impl true
  def update(%{item: item, scope: scope} = _assigns, socket) do
    changeset = InventoryItem.changeset(item, %{})

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:item, item)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"inventory_item" => params}, socket) do
    changeset =
      socket.assigns.item
      |> InventoryItem.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"inventory_item" => params}, socket) do
    save_item(socket, socket.assigns.item.id, params)
  end

  defp save_item(socket, nil, params) do
    case InventoryItems.create_item(socket.assigns.scope, params) do
      {:ok, item} ->
        send(self(), {__MODULE__, :saved, item})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_item(socket, _id, params) do
    case InventoryItems.update_item(socket.assigns.scope, socket.assigns.item, params) do
      {:ok, item} ->
        send(self(), {__MODULE__, :saved, item})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "inventory_item"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:unit]} type="text" label="Unit" placeholder="ml / g / count / pack" />
        <.input field={@form[:quantity]} type="number" label="Quantity" min="0" />
        <.input field={@form[:min_quantity]} type="number" label="Low Stock Threshold" min="0" />
        <.input field={@form[:category]} type="text" label="Category" />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <div class="mt-4">
          <.button type="submit" variant="primary" phx-disable-with="Saving...">Save Item</.button>
        </div>
      </.form>
    </div>
    """
  end
end
