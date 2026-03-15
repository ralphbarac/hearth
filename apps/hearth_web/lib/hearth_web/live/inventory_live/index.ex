defmodule HearthWeb.InventoryLive.Index do
  use HearthWeb, :live_view

  alias HearthInventory.InventoryItems
  alias HearthInventory.InventoryItem
  alias HearthWeb.InventoryLive.ItemFormComponent
  alias HearthGrocery.GroceryLists
  alias HearthGrocery.GroceryItems
  alias Hearth.Links
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "inventory") do
      {:ok,
       socket
       |> put_flash(:error, "Inventory is not enabled for your account.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: InventoryItems.subscribe(scope)

      grocery_lists =
        if Accounts.feature_enabled?(scope, "grocery"),
          do: GroceryLists.list_grocery_lists(scope),
          else: []

      {:ok,
       socket
       |> assign(page_title: "Inventory", active_nav: :inventory)
       |> assign(show_form: :none, editing_item: nil)
       |> assign(grocery_lists: grocery_lists, adding_to_grocery: nil)
       |> load_items()}
    end
  end

  @impl true
  def handle_event("new_item", _params, socket) do
    {:noreply, assign(socket, show_form: :item, editing_item: %InventoryItem{})}
  end

  def handle_event("edit_item", %{"id" => id}, socket) do
    item = InventoryItems.get_item!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: :item, editing_item: item)}
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    item = InventoryItems.get_item!(socket.assigns.current_scope, id)
    {:ok, _} = InventoryItems.delete_item(socket.assigns.current_scope, item)

    {:noreply,
     socket
     |> put_flash(:info, "Item deleted.")
     |> load_items()}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: :none, editing_item: nil)}
  end

  def handle_event("increment", %{"id" => id}, socket) do
    item = InventoryItems.get_item!(socket.assigns.current_scope, id)
    {:ok, _} = InventoryItems.adjust_quantity(socket.assigns.current_scope, item, 1)
    {:noreply, load_items(socket)}
  end

  def handle_event("decrement", %{"id" => id}, socket) do
    item = InventoryItems.get_item!(socket.assigns.current_scope, id)
    {:ok, _} = InventoryItems.adjust_quantity(socket.assigns.current_scope, item, -1)
    {:noreply, load_items(socket)}
  end

  def handle_event("add_to_grocery", %{"id" => id}, socket) do
    item = InventoryItems.get_item!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, adding_to_grocery: item)}
  end

  def handle_event("cancel_add_to_grocery", _params, socket) do
    {:noreply, assign(socket, adding_to_grocery: nil)}
  end

  def handle_event("confirm_add_to_grocery", %{"list_id" => list_id}, socket) do
    scope = socket.assigns.current_scope
    item = socket.assigns.adding_to_grocery
    list = GroceryLists.get_grocery_list!(scope, list_id)

    {:ok, _grocery_item} =
      GroceryItems.create_item(scope, list, %{
        "name" => item.name,
        "quantity" => if(item.unit, do: "1 #{item.unit}", else: "1")
      })

    Links.create_link(scope, "inventory_item", item.id, "grocery_list", list_id)

    {:noreply,
     socket
     |> put_flash(:info, "#{item.name} added to #{list.name}.")
     |> assign(adding_to_grocery: nil)}
  end

  @impl true
  def handle_info({ItemFormComponent, :saved, _item}, socket) do
    {:noreply,
     socket
     |> assign(show_form: :none, editing_item: nil)
     |> load_items()}
  end

  def handle_info({InventoryItems, _action, _item}, socket) do
    {:noreply, load_items(socket)}
  end

  defp load_items(socket) do
    scope = socket.assigns.current_scope

    assign(socket,
      items: InventoryItems.list_items(scope),
      low_stock_items: InventoryItems.list_low_stock_items(scope)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Inventory
        <:actions>
          <.button phx-click="new_item" variant="primary">Add Item</.button>
        </:actions>
      </.header>

      <%!-- Add-to-grocery modal --%>
      <div :if={@adding_to_grocery} class="modal modal-open">
        <div class="modal-box">
          <h3 class="font-bold text-lg mb-4">Add to Grocery List</h3>
          <p class="text-sm text-base-content/70 mb-4">
            Add <strong>{@adding_to_grocery.name}</strong> to a grocery list:
          </p>
          <form phx-submit="confirm_add_to_grocery">
            <select name="list_id" class="select select-bordered w-full mb-4">
              <%= for list <- @grocery_lists do %>
                <option value={list.id}>{list.name}</option>
              <% end %>
            </select>
            <div class="modal-action">
              <button type="submit" class="btn btn-primary">Add to List</button>
              <button type="button" phx-click="cancel_add_to_grocery" class="btn">Cancel</button>
            </div>
          </form>
        </div>
        <div class="modal-backdrop" phx-click="cancel_add_to_grocery"></div>
      </div>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form != :none && "hidden md:block"]}>
          <%!-- Low Stock Alert Section --%>
          <div :if={@low_stock_items != []} class="mb-6">
            <div class="alert alert-warning mb-3">
              <.icon name="hero-exclamation-triangle" class="size-5" />
              <span class="font-medium">
                {length(@low_stock_items)} item{if length(@low_stock_items) != 1, do: "s"} running low
              </span>
            </div>
            <div class="space-y-2">
              <%= for item <- @low_stock_items do %>
                <div class="card bg-warning/10 border border-warning/30">
                  <div class="card-body p-3 flex flex-row items-center gap-3">
                    <div class="flex-1 min-w-0">
                      <p class="font-medium truncate">{item.name}</p>
                      <p class="text-sm text-base-content/60">
                        {item.quantity}{if item.unit, do: " #{item.unit}"} / min {item.min_quantity}{if item.unit,
                          do: " #{item.unit}"}
                      </p>
                    </div>
                    <div class="flex gap-1 shrink-0 items-center">
                      <.button
                        phx-click="decrement"
                        phx-value-id={item.id}
                        class="btn btn-ghost btn-xs btn-circle"
                        aria-label="Decrease quantity"
                        disabled={item.quantity == 0}
                      >
                        −
                      </.button>
                      <span class="font-semibold tabular-nums w-8 text-center">{item.quantity}</span>
                      <.button
                        phx-click="increment"
                        phx-value-id={item.id}
                        class="btn btn-ghost btn-xs btn-circle"
                        aria-label="Increase quantity"
                      >
                        +
                      </.button>
                      <.button
                        :if={@grocery_lists != []}
                        phx-click="add_to_grocery"
                        phx-value-id={item.id}
                        class="btn btn-warning btn-xs ml-2"
                      >
                        Add to Grocery List
                      </.button>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Full Item List --%>
          <%= if @items == [] do %>
            <.empty_state
              icon="hero-archive-box"
              message="No inventory items yet. Add one to get started!"
            />
          <% else %>
            <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3">
              All Items
            </h2>
            <div class="space-y-2">
              <%= for item <- @items do %>
                <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                  <div class="card-body p-3 flex flex-row items-center gap-3">
                    <div class="flex-1 min-w-0">
                      <p class="font-medium truncate">{item.name}</p>
                      <p class="text-sm text-base-content/60">
                        {if item.category, do: "#{item.category} · "}{if item.unit,
                          do: item.unit,
                          else: "units"}
                      </p>
                    </div>
                    <div class="flex gap-1 shrink-0 items-center">
                      <.button
                        phx-click="decrement"
                        phx-value-id={item.id}
                        class="btn btn-ghost btn-xs btn-circle"
                        aria-label="Decrease quantity"
                        disabled={item.quantity == 0}
                      >
                        −
                      </.button>
                      <span class="font-semibold tabular-nums w-8 text-center">{item.quantity}</span>
                      <.button
                        phx-click="increment"
                        phx-value-id={item.id}
                        class="btn btn-ghost btn-xs btn-circle"
                        aria-label="Increase quantity"
                      >
                        +
                      </.button>
                    </div>
                    <div class="flex gap-1 shrink-0">
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

        <div :if={@show_form != :none} class="w-full md:w-96 shrink-0">
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
                <.button
                  phx-click="close_form"
                  class="btn btn-ghost btn-sm btn-circle"
                  aria-label="Close"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>
              <.live_component
                module={ItemFormComponent}
                id={(@editing_item && @editing_item.id) || "new-item"}
                item={@editing_item}
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
