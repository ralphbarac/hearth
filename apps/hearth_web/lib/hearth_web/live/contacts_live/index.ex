defmodule HearthWeb.ContactsLive.Index do
  use HearthWeb, :live_view

  alias HearthContacts.Contacts
  alias HearthContacts.Contact
  alias HearthWeb.ContactsLive.ContactFormComponent
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "contacts") do
      {:ok,
       socket
       |> put_flash(:error, "Contacts is not enabled for your household.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: Contacts.subscribe(scope)

      {:ok,
       socket
       |> assign(page_title: "Contacts", active_nav: :contacts)
       |> assign(show_form: false, editing_contact: nil, search_query: "")
       |> load_contacts()}
    end
  end

  @impl true
  def handle_event("new_contact", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_contact: %Contact{})}
  end

  def handle_event("edit_contact", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, editing_contact: contact)}
  end

  def handle_event("delete_contact", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(socket.assigns.current_scope, id)
    {:ok, _} = Contacts.delete_contact(socket.assigns.current_scope, contact)

    {:noreply,
     socket
     |> put_flash(:info, "Contact deleted.")
     |> load_contacts()}
  end

  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(socket.assigns.current_scope, id)
    {:ok, _} = Contacts.toggle_favorite(socket.assigns.current_scope, contact)
    {:noreply, load_contacts(socket)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(search_query: query)
     |> load_contacts()}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_contact: nil)}
  end

  @impl true
  def handle_info({ContactFormComponent, :saved, _contact}, socket) do
    {:noreply,
     socket
     |> assign(show_form: false, editing_contact: nil)
     |> load_contacts()}
  end

  def handle_info({Contacts, _action, _contact}, socket) do
    {:noreply, load_contacts(socket)}
  end

  defp load_contacts(socket) do
    scope = socket.assigns.current_scope
    query = socket.assigns.search_query

    contacts =
      if query != "" do
        Contacts.search_contacts(scope, query)
      else
        Contacts.list_contacts(scope)
      end

    contacts_by_category = Enum.group_by(contacts, &(&1.category || "Uncategorized"))
    assign(socket, contacts: contacts, contacts_by_category: contacts_by_category)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Contacts
        <:actions>
          <.button phx-click="new_contact" variant="primary">Add Contact</.button>
        </:actions>
      </.header>

      <div class="mt-4">
        <input
          type="text"
          placeholder="Search contacts…"
          value={@search_query}
          phx-keyup="search"
          phx-value-query={@search_query}
          phx-debounce="300"
          class="input input-bordered w-full max-w-sm"
        />
      </div>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form && "hidden md:block"]}>
          <%= if @contacts == [] do %>
            <.empty_state icon="hero-user-group" message="No contacts yet. Add your first one!" />
          <% else %>
            <%= for {category, contacts} <- Enum.sort_by(@contacts_by_category, fn {k, _} -> k end) do %>
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3 mt-4">
                {category}
              </h2>
              <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 mb-4">
                <%= for contact <- contacts do %>
                  <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <div class="flex-1 min-w-0">
                          <p class="font-semibold truncate">{contact.name}</p>
                          <%= if contact.role do %>
                            <p class="text-sm text-base-content/60">{contact.role}</p>
                          <% end %>
                        </div>
                        <button
                          phx-click="toggle_favorite"
                          phx-value-id={contact.id}
                          class="btn btn-ghost btn-xs btn-circle"
                          title={if contact.is_favorite, do: "Remove from favorites", else: "Add to favorites"}
                        >
                          <.icon
                            name={if contact.is_favorite, do: "hero-star-solid", else: "hero-star"}
                            class={["size-4", contact.is_favorite && "text-warning"]}
                          />
                        </button>
                      </div>
                      <div class="mt-2 space-y-1 text-sm text-base-content/70">
                        <%= if contact.phone do %>
                          <p><.icon name="hero-phone" class="size-3.5 inline mr-1" />{contact.phone}</p>
                        <% end %>
                        <%= if contact.email do %>
                          <p><.icon name="hero-envelope" class="size-3.5 inline mr-1" />{contact.email}</p>
                        <% end %>
                      </div>
                      <div class="flex gap-1 mt-3">
                        <.button
                          phx-click="edit_contact"
                          phx-value-id={contact.id}
                          class="btn btn-ghost btn-xs"
                        >
                          Edit
                        </.button>
                        <.button
                          phx-click="delete_contact"
                          phx-value-id={contact.id}
                          data-confirm="Delete this contact?"
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
          <% end %>
        </div>

        <div :if={@show_form} class="w-full md:w-96 shrink-0">
          <div class="flex items-center gap-2 mb-4 md:hidden">
            <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Back">
              <.icon name="hero-arrow-left" class="size-4" />
            </.button>
            <span class="font-medium">
              {if @editing_contact && @editing_contact.id, do: "Edit Contact", else: "New Contact"}
            </span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">
                  {if @editing_contact && @editing_contact.id, do: "Edit Contact", else: "New Contact"}
                </h3>
                <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Close">
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>
              <.live_component
                module={ContactFormComponent}
                id={(@editing_contact && @editing_contact.id) || "new"}
                contact={@editing_contact}
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
