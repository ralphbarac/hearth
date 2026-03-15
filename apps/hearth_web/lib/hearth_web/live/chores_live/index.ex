defmodule HearthWeb.ChoresLive.Index do
  use HearthWeb, :live_view

  alias HearthChores.Chores
  alias HearthChores.Chore
  alias HearthWeb.ChoresLive.ChoreFormComponent
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "chores") do
      {:ok,
       socket
       |> put_flash(:error, "Chores is not enabled for your household.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: Chores.subscribe(scope)

      household_users = Accounts.list_household_users(scope)

      {:ok,
       socket
       |> assign(page_title: "Chore Board", active_nav: :chores)
       |> assign(show_form: false, editing_chore: nil, filter_user_id: nil)
       |> assign(household_users: household_users)
       |> load_chores()}
    end
  end

  @impl true
  def handle_event("new_chore", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_chore: %Chore{})}
  end

  def handle_event("edit_chore", %{"id" => id}, socket) do
    chore = Chores.get_chore!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, editing_chore: chore)}
  end

  def handle_event("delete_chore", %{"id" => id}, socket) do
    chore = Chores.get_chore!(socket.assigns.current_scope, id)
    {:ok, _} = Chores.delete_chore(socket.assigns.current_scope, chore)

    {:noreply,
     socket
     |> put_flash(:info, "Chore deleted.")
     |> load_chores()}
  end

  def handle_event("complete_chore", %{"id" => id}, socket) do
    chore = Chores.get_chore!(socket.assigns.current_scope, id)
    {:ok, _} = Chores.complete_chore(socket.assigns.current_scope, chore)

    {:noreply,
     socket
     |> put_flash(:info, "Chore marked as complete!")
     |> load_chores()}
  end

  def handle_event("filter_user", %{"user_id" => user_id}, socket) do
    filter = if user_id == "", do: nil, else: user_id
    {:noreply, socket |> assign(filter_user_id: filter) |> load_chores()}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_chore: nil)}
  end

  @impl true
  def handle_info({ChoreFormComponent, :saved, _chore}, socket) do
    {:noreply,
     socket
     |> assign(show_form: false, editing_chore: nil)
     |> load_chores()}
  end

  def handle_info({Chores, _action, _chore}, socket) do
    {:noreply, load_chores(socket)}
  end

  defp load_chores(socket) do
    scope = socket.assigns.current_scope
    filter_user_id = socket.assigns.filter_user_id
    today = Date.utc_today()

    chores =
      if filter_user_id do
        Chores.list_chores_for_user(scope, filter_user_id)
      else
        Chores.list_chores(scope)
      end

    {due_chores, upcoming_chores} = Enum.split_with(chores, fn c ->
      c.is_active and Date.compare(c.next_due_date, today) != :gt
    end)

    assign(socket, chores: chores, due_chores: due_chores, upcoming_chores: upcoming_chores)
  end

  defp color_class("blue"), do: "bg-info"
  defp color_class("green"), do: "bg-success"
  defp color_class("amber"), do: "bg-warning"
  defp color_class("rose"), do: "bg-error"
  defp color_class("purple"), do: "bg-purple-500"
  defp color_class(_), do: "bg-slate-400"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Chore Board
        <:actions>
          <.button phx-click="new_chore" variant="primary">Add Chore</.button>
        </:actions>
      </.header>

      <%!-- Assignee filter tabs --%>
      <div class="mt-4 flex flex-wrap gap-2">
        <button
          phx-click="filter_user"
          phx-value-user_id=""
          class={["btn btn-sm", is_nil(@filter_user_id) && "btn-primary", is_nil(@filter_user_id) || "btn-ghost"]}
        >
          All
        </button>
        <%= for user <- @household_users do %>
          <button
            phx-click="filter_user"
            phx-value-user_id={user.id}
            class={["btn btn-sm", @filter_user_id == user.id && "btn-primary", @filter_user_id == user.id || "btn-ghost"]}
          >
            {user.username || user.email}
          </button>
        <% end %>
      </div>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form && "hidden md:block"]}>
          <h2 class="text-sm font-semibold uppercase tracking-wide text-error mb-3">
            Due / Overdue
          </h2>
          <%= if @due_chores == [] do %>
            <p class="text-base-content/50 text-sm mb-6">Nothing overdue.</p>
          <% else %>
            <div class="grid gap-3 sm:grid-cols-2 mb-6">
              <%= for chore <- @due_chores do %>
                <.chore_card chore={chore} color_class={color_class(chore.color)} />
              <% end %>
            </div>
          <% end %>

          <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3">
            Upcoming
          </h2>
          <%= if @upcoming_chores == [] do %>
            <.empty_state icon="hero-check-circle" message="No chores yet. Add your first one!" />
          <% else %>
            <div class="grid gap-3 sm:grid-cols-2">
              <%= for chore <- @upcoming_chores do %>
                <.chore_card chore={chore} color_class={color_class(chore.color)} />
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
              {if @editing_chore && @editing_chore.id, do: "Edit Chore", else: "New Chore"}
            </span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">
                  {if @editing_chore && @editing_chore.id, do: "Edit Chore", else: "New Chore"}
                </h3>
                <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Close">
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>
              <.live_component
                module={ChoreFormComponent}
                id={(@editing_chore && @editing_chore.id) || "new"}
                chore={@editing_chore}
                scope={@current_scope}
                household_users={@household_users}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp chore_card(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
      <div class="card-body p-4">
        <div class="flex items-start gap-3">
          <div class={["w-3 h-3 rounded-full mt-1.5 shrink-0", @color_class]}></div>
          <div class="flex-1 min-w-0">
            <p class="font-semibold truncate">{@chore.name}</p>
            <p class="text-xs text-base-content/60 mt-0.5">
              Due: {Date.to_string(@chore.next_due_date)}
              &bull; {String.capitalize(@chore.frequency)}
            </p>
            <%= if @chore.assigned_to do %>
              <p class="text-xs text-base-content/50 mt-0.5">
                <.icon name="hero-user" class="size-3 inline mr-0.5" />
                {@chore.assigned_to.username || @chore.assigned_to.email}
              </p>
            <% end %>
          </div>
        </div>
        <div class="flex gap-1 mt-3">
          <.button
            phx-click="complete_chore"
            phx-value-id={@chore.id}
            class="btn btn-success btn-xs"
          >
            Complete
          </.button>
          <.button
            phx-click="edit_chore"
            phx-value-id={@chore.id}
            class="btn btn-ghost btn-xs"
          >
            Edit
          </.button>
          <.button
            phx-click="delete_chore"
            phx-value-id={@chore.id}
            data-confirm="Delete this chore?"
            class="btn btn-ghost btn-xs text-error"
          >
            Delete
          </.button>
        </div>
      </div>
    </div>
    """
  end
end
