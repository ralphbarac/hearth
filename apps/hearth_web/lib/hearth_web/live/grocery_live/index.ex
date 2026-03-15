defmodule HearthWeb.GroceryLive.Index do
  use HearthWeb, :live_view

  alias HearthGrocery.GroceryLists
  alias HearthGrocery.GroceryItems
  alias HearthGrocery.GroceryList
  alias HearthGrocery.GroceryItem
  alias HearthWeb.GroceryLive.ListFormComponent
  alias HearthWeb.GroceryLive.ItemFormComponent
  alias Hearth.Links
  alias Hearth.Accounts
  alias HearthCalendar.Events

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "grocery") do
      {:ok,
       socket
       |> put_flash(:error, "Grocery is not enabled for your account.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: GroceryLists.subscribe(scope)

      {:ok,
       assign(socket,
         page_title: "Grocery",
         active_nav: :grocery,
         lists: GroceryLists.list_grocery_lists(scope),
         selected_list_id: nil,
         items: [],
         show_form: :none,
         editing_list: nil,
         editing_item: nil,
         linked_event_ids: [],
         events_for_linking: []
       )}
    end
  end

  @impl true
  def handle_event("new_list", _params, socket) do
    {:noreply, assign(socket, show_form: :list, editing_list: %GroceryList{})}
  end

  def handle_event("edit_list", %{"id" => id}, socket) do
    list = GroceryLists.get_grocery_list!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: :list, editing_list: list)}
  end

  def handle_event("delete_list", %{"id" => id}, socket) do
    list = GroceryLists.get_grocery_list!(socket.assigns.current_scope, id)
    {:ok, _} = GroceryLists.delete_grocery_list(socket.assigns.current_scope, list)

    selected_list_id =
      if socket.assigns.selected_list_id == id, do: nil, else: socket.assigns.selected_list_id

    items = if selected_list_id == nil, do: [], else: socket.assigns.items

    {:noreply,
     socket
     |> put_flash(:info, "List deleted.")
     |> assign(
       lists: GroceryLists.list_grocery_lists(socket.assigns.current_scope),
       selected_list_id: selected_list_id,
       items: items
     )}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: :none, editing_list: nil, editing_item: nil)}
  end

  def handle_event("select_list", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    list = GroceryLists.get_grocery_list!(scope, id)
    items = GroceryItems.list_items(scope, list)
    linked_event_ids = Links.get_linked_ids(scope, "grocery_list", id, "calendar_event")
    events_for_linking = Events.list_events(scope)

    {:noreply,
     assign(socket,
       selected_list_id: id,
       items: items,
       linked_event_ids: linked_event_ids,
       events_for_linking: events_for_linking
     )}
  end

  def handle_event("deselect_list", _params, socket) do
    {:noreply,
     assign(socket,
       selected_list_id: nil,
       items: [],
       linked_event_ids: [],
       events_for_linking: []
     )}
  end

  def handle_event("new_item", _params, socket) do
    {:noreply, assign(socket, show_form: :item, editing_item: %GroceryItem{})}
  end

  def handle_event("edit_item", %{"id" => id}, socket) do
    item = GroceryItems.get_item!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: :item, editing_item: item)}
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    item = GroceryItems.get_item!(socket.assigns.current_scope, id)
    {:ok, _} = GroceryItems.delete_item(socket.assigns.current_scope, item)

    items = reload_items(socket)

    {:noreply,
     socket
     |> put_flash(:info, "Item deleted.")
     |> assign(items: items)}
  end

  def handle_event("toggle_item", %{"id" => id}, socket) do
    item = GroceryItems.get_item!(socket.assigns.current_scope, id)
    {:ok, _} = GroceryItems.toggle_checked(socket.assigns.current_scope, item)
    {:noreply, assign(socket, items: reload_items(socket))}
  end

  def handle_event("toggle_event_link", %{"event_id" => event_id}, socket) do
    scope = socket.assigns.current_scope
    list_id = socket.assigns.selected_list_id
    Links.toggle_link(scope, "calendar_event", event_id, "grocery_list", list_id)
    linked_event_ids = Links.get_linked_ids(scope, "grocery_list", list_id, "calendar_event")
    {:noreply, assign(socket, linked_event_ids: linked_event_ids)}
  end

  @impl true
  def handle_info({ListFormComponent, :saved, _list}, socket) do
    {:noreply,
     socket
     |> assign(show_form: :none, editing_list: nil)
     |> assign(lists: GroceryLists.list_grocery_lists(socket.assigns.current_scope))}
  end

  def handle_info({ItemFormComponent, :saved, _item}, socket) do
    {:noreply,
     socket
     |> assign(show_form: :none, editing_item: nil)
     |> assign(items: reload_items(socket))}
  end

  def handle_info({GroceryLists, _action, _list}, socket) do
    {:noreply,
     assign(socket, lists: GroceryLists.list_grocery_lists(socket.assigns.current_scope))}
  end

  def handle_info({GroceryItems, _action, _item}, socket) do
    {:noreply, assign(socket, items: reload_items(socket))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Grocery
        <:actions>
          <.button phx-click="new_list" variant="primary">Add List</.button>
        </:actions>
      </.header>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form != :none && "hidden md:block"]}>
          <%= if @lists == [] do %>
            <.empty_state
              icon="hero-shopping-cart"
              message="No grocery lists yet. Add one to get started!"
            />
          <% else %>
            <div class="space-y-4">
              <%= for list <- @lists do %>
                <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                  <div class="card-body p-4">
                    <div class="flex items-start justify-between gap-3">
                      <div class="flex-1 min-w-0">
                        <p class="font-semibold text-lg truncate">{list.name}</p>
                        <p :if={list.notes} class="text-sm text-base-content/60 truncate">
                          {list.notes}
                        </p>
                      </div>
                      <div class="flex gap-1 shrink-0 items-center">
                        <.button
                          phx-click={
                            if @selected_list_id == list.id, do: "deselect_list", else: "select_list"
                          }
                          phx-value-id={list.id}
                          class="btn btn-ghost btn-sm"
                        >
                          {if @selected_list_id == list.id, do: "Close", else: "Open"}
                        </.button>
                        <.button
                          phx-click="edit_list"
                          phx-value-id={list.id}
                          class="btn btn-ghost btn-xs"
                        >
                          Edit
                        </.button>
                        <.button
                          phx-click="delete_list"
                          phx-value-id={list.id}
                          data-confirm="Delete this list and all its items?"
                          class="btn btn-ghost btn-xs text-error"
                        >
                          Delete
                        </.button>
                      </div>
                    </div>

                    <%= if @selected_list_id == list.id do %>
                      <div class="mt-4 border-t border-base-200 pt-4">
                        <div class="flex items-center justify-between mb-3">
                          <span class="text-sm font-medium text-base-content/60">
                            {length(@items)} item{if length(@items) != 1, do: "s"}
                          </span>
                          <.button phx-click="new_item" class="btn btn-ghost btn-xs">
                            + Add Item
                          </.button>
                        </div>

                        <%= if @items == [] do %>
                          <p class="text-base-content/50 text-sm text-center py-4">
                            No items yet. Add one!
                          </p>
                        <% else %>
                          <div class="space-y-1">
                            <%= for item <- @items do %>
                              <div class={[
                                "flex items-center gap-2 p-2 rounded-lg hover:bg-base-200",
                                item.checked && "opacity-60"
                              ]}>
                                <input
                                  type="checkbox"
                                  class="checkbox checkbox-sm"
                                  checked={item.checked}
                                  phx-click="toggle_item"
                                  phx-value-id={item.id}
                                />
                                <div class="flex-1 min-w-0">
                                  <span class={["text-sm", item.checked && "line-through"]}>
                                    {item.name}
                                  </span>
                                  <span :if={item.quantity} class="text-xs text-base-content/50 ml-1">
                                    ({item.quantity})
                                  </span>
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
                            <% end %>
                          </div>
                        <% end %>
                      </div>

                      <div class="mt-4 border-t border-base-200 pt-4">
                        <h4 class="text-sm font-medium text-base-content/60 mb-2">Linked Events</h4>
                        <%= for event <- linked_items(@events_for_linking, @linked_event_ids) do %>
                          <div class="flex items-center justify-between text-sm py-1">
                            <span class="truncate flex-1">
                              <.icon name="hero-calendar" class="size-3 inline" />
                              {event.title} &ndash; {Calendar.strftime(event.starts_at, "%b %-d")}
                            </span>
                            <.button
                              phx-click="toggle_event_link"
                              phx-value-event_id={event.id}
                              class="btn btn-ghost btn-xs text-error shrink-0 ml-2"
                            >
                              Unlink
                            </.button>
                          </div>
                        <% end %>
                        <% unlinked_events =
                          Enum.filter(@events_for_linking, fn e -> e.id not in @linked_event_ids end) %>
                        <%= if unlinked_events != [] do %>
                          <form phx-submit="toggle_event_link" class="flex gap-2 mt-2">
                            <select name="event_id" class="select select-bordered select-xs flex-1">
                              <%= for event <- unlinked_events do %>
                                <option value={event.id}>
                                  {event.title} &ndash; {Calendar.strftime(event.starts_at, "%b %-d")}
                                </option>
                              <% end %>
                            </select>
                            <button type="submit" class="btn btn-xs btn-primary">Link</button>
                          </form>
                        <% end %>
                        <%= if @events_for_linking == [] do %>
                          <p class="text-xs text-base-content/50">No events to link</p>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div :if={@show_form != :none} class="w-full md:w-96 shrink-0">
          <% form_title =
            cond do
              @show_form == :list && @editing_list && @editing_list.id -> "Edit List"
              @show_form == :list -> "New List"
              @show_form == :item && @editing_item && @editing_item.id -> "Edit Item"
              true -> "New Item"
            end %>
          <div class="flex items-center gap-2 mb-4 md:hidden">
            <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Back">
              <.icon name="hero-arrow-left" class="size-4" />
            </.button>
            <span class="font-medium">{form_title}</span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">{form_title}</h3>
                <.button
                  phx-click="close_form"
                  class="btn btn-ghost btn-sm btn-circle"
                  aria-label="Close"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>

              <%= if @show_form == :list do %>
                <.live_component
                  module={ListFormComponent}
                  id={(@editing_list && @editing_list.id) || "new-list"}
                  list={@editing_list}
                  scope={@current_scope}
                />
              <% end %>

              <%= if @show_form == :item do %>
                <.live_component
                  module={ItemFormComponent}
                  id={(@editing_item && @editing_item.id) || "new-item"}
                  item={@editing_item}
                  list_id={@selected_list_id}
                  scope={@current_scope}
                />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp linked_items(all_items, linked_ids) do
    Enum.filter(all_items, fn item -> item.id in linked_ids end)
  end

  defp reload_items(socket) do
    case socket.assigns.selected_list_id do
      nil ->
        []

      list_id ->
        list = GroceryLists.get_grocery_list!(socket.assigns.current_scope, list_id)
        GroceryItems.list_items(socket.assigns.current_scope, list)
    end
  end
end
