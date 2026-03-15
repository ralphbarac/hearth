defmodule HearthWeb.GroceryLive.ListFormComponent do
  use HearthWeb, :live_component

  alias HearthGrocery.GroceryLists
  alias HearthGrocery.GroceryList

  @impl true
  def update(%{list: list, scope: scope} = _assigns, socket) do
    changeset = GroceryList.changeset(list, %{})

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:list, list)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"grocery_list" => params}, socket) do
    changeset =
      socket.assigns.list
      |> GroceryList.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"grocery_list" => params}, socket) do
    save_list(socket, socket.assigns.list.id, params)
  end

  defp save_list(socket, nil, params) do
    case GroceryLists.create_grocery_list(socket.assigns.scope, params) do
      {:ok, list} ->
        send(self(), {__MODULE__, :saved, list})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_list(socket, _id, params) do
    case GroceryLists.update_grocery_list(socket.assigns.scope, socket.assigns.list, params) do
      {:ok, list} ->
        send(self(), {__MODULE__, :saved, list})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "grocery_list"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <.input field={@form[:is_active]} type="checkbox" label="Active" />
        <div class="mt-4">
          <.button type="submit" variant="primary" phx-disable-with="Saving...">Save List</.button>
        </div>
      </.form>
    </div>
    """
  end
end
