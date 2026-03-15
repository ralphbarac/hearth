defmodule HearthWeb.GroceryLive.ItemFormComponent do
  use HearthWeb, :live_component

  alias HearthGrocery.GroceryItems
  alias HearthGrocery.GroceryLists
  alias HearthGrocery.GroceryItem

  @impl true
  def update(%{item: item, list_id: list_id, scope: scope} = _assigns, socket) do
    changeset = GroceryItem.changeset(item, %{})

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:item, item)
     |> assign(:list_id, list_id)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"grocery_item" => params}, socket) do
    changeset =
      socket.assigns.item
      |> GroceryItem.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"grocery_item" => params}, socket) do
    save_item(socket, socket.assigns.item.id, params)
  end

  defp save_item(socket, nil, params) do
    list = GroceryLists.get_grocery_list!(socket.assigns.scope, socket.assigns.list_id)

    case GroceryItems.create_item(socket.assigns.scope, list, params) do
      {:ok, item} ->
        send(self(), {__MODULE__, :saved, item})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_item(socket, _id, params) do
    case GroceryItems.update_item(socket.assigns.scope, socket.assigns.item, params) do
      {:ok, item} ->
        send(self(), {__MODULE__, :saved, item})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "grocery_item"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:quantity]} type="text" label="Quantity" />
        <.input field={@form[:category]} type="text" label="Category" />
        <div class="mt-4">
          <.button type="submit" variant="primary" phx-disable-with="Saving...">Save Item</.button>
        </div>
      </.form>
    </div>
    """
  end
end
