defmodule HearthWeb.CalendarLive.Index do
  use HearthWeb, :live_view

  alias HearthCalendar.Events
  alias HearthCalendar.Event
  alias HearthWeb.CalendarLive.EventFormComponent
  alias Hearth.Links
  alias Hearth.Accounts
  alias HearthGrocery.GroceryLists
  alias HearthBudget.Transactions
  alias HearthRecipes.Recipes

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "calendar") do
      {:ok,
       socket
       |> put_flash(:error, "Calendar is not enabled for your account.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: Events.subscribe(scope)

      today = Date.utc_today()
      current_month = Date.new!(today.year, today.month, 1)
      weeks = calendar_weeks(current_month)
      {from_date, to_date} = date_range(weeks)

      {:ok,
       assign(socket,
         page_title: "Calendar",
         active_nav: :calendar,
         current_month: current_month,
         selected_date: nil,
         events: Events.list_events_for_range(scope, from_date, to_date),
         weeks: weeks,
         grocery_lists: GroceryLists.list_grocery_lists(scope),
         show_form: false,
         editing_event: nil,
         prefill_date: nil,
         editing_as_detached: nil,
         recurrence_modal: nil,
         linked_grocery_list_ids: [],
         linked_transaction_ids: [],
         linkable_transactions: [],
         linked_recipe_ids: [],
         linkable_recipes: []
       )}
    end
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    {:noreply, load_month(socket, Date.shift(socket.assigns.current_month, month: -1))}
  end

  def handle_event("next_month", _params, socket) do
    {:noreply, load_month(socket, Date.shift(socket.assigns.current_month, month: 1))}
  end

  def handle_event("today", _params, socket) do
    today = Date.utc_today()
    socket = load_month(socket, Date.new!(today.year, today.month, 1))
    {:noreply, assign(socket, selected_date: today)}
  end

  def handle_event("select_date", %{"date" => date_str}, socket) do
    {:noreply, assign(socket, selected_date: Date.from_iso8601!(date_str))}
  end

  def handle_event("deselect_date", _params, socket) do
    {:noreply, assign(socket, selected_date: nil)}
  end

  def handle_event("new_event", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_event: %Event{}, prefill_date: nil)}
  end

  def handle_event("new_event_on_date", %{"date" => date_str}, socket) do
    date = Date.from_iso8601!(date_str)
    {:noreply, assign(socket, show_form: true, editing_event: %Event{}, prefill_date: date)}
  end

  def handle_event("edit_event", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    event = Events.get_event!(scope, id)

    linked_grocery_list_ids =
      Links.get_linked_ids(scope, "calendar_event", event.id, "grocery_list")

    linked_transaction_ids =
      Links.get_linked_ids(scope, "calendar_event", event.id, "budget_transaction")

    linked_recipe_ids = Links.get_linked_ids(scope, "calendar_event", event.id, "recipe")

    today = Date.utc_today()

    linkable_transactions =
      Transactions.list_transactions_for_month(scope, {today.year, today.month})

    linkable_recipes =
      if Accounts.feature_enabled?(scope, "recipes"), do: Recipes.list_recipes(scope), else: []

    {:noreply,
     assign(socket,
       show_form: true,
       editing_event: event,
       prefill_date: nil,
       linked_grocery_list_ids: linked_grocery_list_ids,
       linked_transaction_ids: linked_transaction_ids,
       linked_recipe_ids: linked_recipe_ids,
       linkable_transactions: linkable_transactions,
       linkable_recipes: linkable_recipes
     )}
  end

  def handle_event("delete_event", %{"id" => id}, socket) do
    event = Events.get_event!(socket.assigns.current_scope, id)
    {:ok, _} = Events.delete_event(socket.assigns.current_scope, event)

    {:noreply,
     socket
     |> put_flash(:info, "Event deleted.")
     |> reload_events()}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, socket |> reset_form() |> assign(selected_date: nil)}
  end

  def handle_event(
        "show_recurrence_modal",
        %{"series_id" => series_id, "occurrence_date" => date_str},
        socket
      ) do
    {:noreply,
     assign(socket,
       recurrence_modal: %{
         action: :edit,
         series_id: series_id,
         occurrence_date: Date.from_iso8601!(date_str)
       }
     )}
  end

  def handle_event(
        "show_recurrence_modal_delete",
        %{"series_id" => series_id, "occurrence_date" => date_str},
        socket
      ) do
    {:noreply,
     assign(socket,
       recurrence_modal: %{
         action: :delete,
         series_id: series_id,
         occurrence_date: Date.from_iso8601!(date_str)
       }
     )}
  end

  def handle_event("close_recurrence_modal", _params, socket) do
    {:noreply, assign(socket, recurrence_modal: nil)}
  end

  def handle_event("recurrence_edit_occurrence", _params, socket) do
    %{series_id: series_id, occurrence_date: occurrence_date} = socket.assigns.recurrence_modal
    scope = socket.assigns.current_scope
    series = Events.get_event!(scope, series_id)
    occurrence = build_occurrence_for_modal(series, occurrence_date)

    {:noreply,
     assign(socket,
       recurrence_modal: nil,
       show_form: true,
       editing_event: occurrence,
       editing_as_detached: {series_id, occurrence_date},
       prefill_date: nil,
       linked_grocery_list_ids: [],
       linked_transaction_ids: [],
       linkable_transactions: [],
       linked_recipe_ids: [],
       linkable_recipes: []
     )}
  end

  def handle_event("recurrence_edit_series", _params, socket) do
    %{series_id: series_id} = socket.assigns.recurrence_modal
    scope = socket.assigns.current_scope
    series = Events.get_event!(scope, series_id)

    linked_grocery_list_ids =
      Links.get_linked_ids(scope, "calendar_event", series.id, "grocery_list")

    linked_transaction_ids =
      Links.get_linked_ids(scope, "calendar_event", series.id, "budget_transaction")

    linked_recipe_ids = Links.get_linked_ids(scope, "calendar_event", series.id, "recipe")
    today = Date.utc_today()

    linkable_transactions =
      Transactions.list_transactions_for_month(scope, {today.year, today.month})

    linkable_recipes =
      if Accounts.feature_enabled?(scope, "recipes"), do: Recipes.list_recipes(scope), else: []

    {:noreply,
     assign(socket,
       recurrence_modal: nil,
       show_form: true,
       editing_event: series,
       editing_as_detached: nil,
       prefill_date: nil,
       linked_grocery_list_ids: linked_grocery_list_ids,
       linked_transaction_ids: linked_transaction_ids,
       linked_recipe_ids: linked_recipe_ids,
       linkable_transactions: linkable_transactions,
       linkable_recipes: linkable_recipes
     )}
  end

  def handle_event("recurrence_delete_occurrence", _params, socket) do
    %{series_id: series_id, occurrence_date: occurrence_date} = socket.assigns.recurrence_modal
    scope = socket.assigns.current_scope
    series = Events.get_event!(scope, series_id)
    {:ok, _} = Events.add_exception(scope, series, occurrence_date)

    {:noreply,
     socket
     |> put_flash(:info, "Occurrence removed.")
     |> assign(recurrence_modal: nil)
     |> reload_events()}
  end

  def handle_event("recurrence_delete_series", _params, socket) do
    %{series_id: series_id} = socket.assigns.recurrence_modal
    scope = socket.assigns.current_scope
    series = Events.get_event!(scope, series_id)
    {:ok, _} = Events.delete_event(scope, series)

    {:noreply,
     socket
     |> put_flash(:info, "Series deleted.")
     |> assign(recurrence_modal: nil)
     |> reload_events()}
  end

  def handle_event("toggle_grocery_link", %{"list_id" => list_id}, socket) do
    scope = socket.assigns.current_scope
    event = socket.assigns.editing_event
    Links.toggle_link(scope, "calendar_event", event.id, "grocery_list", list_id)

    linked_grocery_list_ids =
      Links.get_linked_ids(scope, "calendar_event", event.id, "grocery_list")

    {:noreply, assign(socket, linked_grocery_list_ids: linked_grocery_list_ids)}
  end

  def handle_event("toggle_transaction_link", %{"transaction_id" => tx_id}, socket) do
    scope = socket.assigns.current_scope
    event = socket.assigns.editing_event
    Links.toggle_link(scope, "calendar_event", event.id, "budget_transaction", tx_id)

    linked_transaction_ids =
      Links.get_linked_ids(scope, "calendar_event", event.id, "budget_transaction")

    {:noreply, assign(socket, linked_transaction_ids: linked_transaction_ids)}
  end

  def handle_event("link_recipe", %{"recipe_id" => recipe_id}, socket) do
    scope = socket.assigns.current_scope
    event = socket.assigns.editing_event
    Links.create_link(scope, "calendar_event", event.id, "recipe", recipe_id)
    linked_recipe_ids = Links.get_linked_ids(scope, "calendar_event", event.id, "recipe")
    {:noreply, assign(socket, linked_recipe_ids: linked_recipe_ids)}
  end

  def handle_event("unlink_recipe", %{"recipe_id" => recipe_id}, socket) do
    scope = socket.assigns.current_scope
    event = socket.assigns.editing_event

    case Links.get_link(scope, "calendar_event", event.id, "recipe", recipe_id) do
      nil ->
        {:noreply, socket}

      link ->
        Links.delete_link(scope, link)
        linked_recipe_ids = Links.get_linked_ids(scope, "calendar_event", event.id, "recipe")
        {:noreply, assign(socket, linked_recipe_ids: linked_recipe_ids)}
    end
  end

  @impl true
  def handle_info({EventFormComponent, :saved, _event}, socket) do
    {:noreply, socket |> reset_form() |> reload_events()}
  end

  def handle_info({Events, _action, _event}, socket) do
    {:noreply, reload_events(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[calc(100svh-3.5rem)] md:h-screen px-4 md:px-6 pt-4 md:pt-5 overflow-hidden">
      <% today = Date.utc_today()
      events_map = events_by_date(@events) %>

      <div class="flex items-center justify-between mb-4 shrink-0">
        <div class="flex items-center gap-1">
          <button
            phx-click="prev_month"
            class="btn btn-ghost btn-sm btn-circle"
            aria-label="Previous month"
          >
            <.icon name="hero-chevron-left" class="size-4" />
          </button>
          <span class="text-lg font-semibold w-44 text-center">
            {Calendar.strftime(@current_month, "%B %Y")}
          </span>
          <button
            phx-click="next_month"
            class="btn btn-ghost btn-sm btn-circle"
            aria-label="Next month"
          >
            <.icon name="hero-chevron-right" class="size-4" />
          </button>
        </div>
        <div class="flex gap-2">
          <button phx-click="today" class="btn btn-ghost btn-sm">Today</button>
          <button phx-click="new_event" class="btn btn-primary btn-sm">+ Add</button>
        </div>
      </div>

      <div class="flex gap-4 flex-1 overflow-hidden min-h-0">
        <div class="flex-1 min-w-0 overflow-x-auto flex flex-col">
          <div class="grid grid-cols-7 pb-2 shrink-0">
            <%= for day <- ~w[Sun Mon Tue Wed Thu Fri Sat] do %>
              <div class="text-center text-xs font-semibold text-base-content/50 uppercase">
                {day}
              </div>
            <% end %>
          </div>

          <div class="border-t border-l border-base-200 flex-1 min-h-0 calendar-grid-body">
            <%= for week <- @weeks do %>
              <div class="grid grid-cols-7 flex-1">
                <%= for date <- week do %>
                  <% is_current = date.month == @current_month.month
                  is_today = date == today
                  is_selected = date == @selected_date
                  d_events = if is_current, do: Map.get(events_map, date, []), else: []
                  chips = Enum.take(d_events, 2)
                  overflow = max(0, length(d_events) - 2) %>
                  <button
                    class={[
                      "w-full h-full text-left border-r border-b border-base-200 p-1 transition-colors",
                      not is_current && "bg-base-200/20",
                      is_selected && "ring-2 ring-primary ring-inset",
                      is_today && not is_selected && "bg-amber-50",
                      is_current && not is_selected && "hover:bg-base-200/40"
                    ]}
                    phx-click="select_date"
                    phx-value-date={Date.to_iso8601(date)}
                  >
                    <div class="flex justify-end mb-0.5">
                      <span class={[
                        "text-sm w-6 h-6 flex items-center justify-center rounded-full",
                        not is_current && "text-base-content/30",
                        is_today && "bg-primary text-primary-content font-bold"
                      ]}>
                        {date.day}
                      </span>
                    </div>

                    <%= for event <- chips do %>
                      <div
                        class={[
                          "text-xs rounded px-1 py-0.5 mb-0.5 truncate border-l-2",
                          chip_class(event.color)
                        ]}
                        phx-click.stop={
                          if event.series_id, do: "show_recurrence_modal", else: "edit_event"
                        }
                        phx-value-id={event.id || event.series_id}
                        phx-value-series_id={event.series_id}
                        phx-value-occurrence_date={
                          event.series_id && Date.to_iso8601(DateTime.to_date(event.starts_at))
                        }
                      >
                        <%= if not event.all_day do %>
                          <span class="opacity-70">{format_chip_time(event)}</span>{" "}
                        <% end %>
                        {event.title}
                      </div>
                    <% end %>

                    <%= if overflow > 0 do %>
                      <div class="text-xs text-primary font-medium">+{overflow} more</div>
                    <% end %>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <div :if={@recurrence_modal} class="modal modal-open">
        <div class="modal-box">
          <h3 class="font-bold text-lg">Recurring event</h3>
          <p class="py-4 text-base-content/70">
            {if @recurrence_modal.action == :edit,
              do: "Edit just this occurrence, or all events in the series?",
              else: "Delete just this occurrence, or the entire series?"}
          </p>
          <div class="modal-action flex-col gap-2">
            <button
              phx-click={
                if @recurrence_modal.action == :edit,
                  do: "recurrence_edit_occurrence",
                  else: "recurrence_delete_occurrence"
              }
              class="btn btn-primary w-full"
            >
              This occurrence only
            </button>
            <button
              phx-click={
                if @recurrence_modal.action == :edit,
                  do: "recurrence_edit_series",
                  else: "recurrence_delete_series"
              }
              class="btn btn-outline w-full"
            >
              All events in series
            </button>
            <button phx-click="close_recurrence_modal" class="btn btn-ghost w-full">Cancel</button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_recurrence_modal"></div>
      </div>
    </div>

    <%!-- Slide-over backdrop --%>
    <div
      class={[
        "fixed inset-0 bg-black/25 z-30 transition-opacity duration-300",
        (@show_form or @selected_date) && "opacity-100" || "opacity-0 pointer-events-none"
      ]}
      phx-click="close_form"
    >
    </div>

    <%!-- Slide-over panel --%>
    <div class={[
      "fixed top-0 right-0 h-full w-full sm:w-96 bg-base-100 shadow-2xl border-l border-base-200 z-40",
      "transform transition-transform duration-300 ease-in-out overflow-y-auto",
      (@show_form or @selected_date) && "translate-x-0" || "translate-x-full"
    ]}>
      <%= if @show_form do %>
        <div class="p-5">
          <div class="flex items-center justify-between mb-4">
            <h3 class="font-semibold text-lg">
              {if @editing_event && @editing_event.id, do: "Edit Event", else: "New Event"}
            </h3>
            <button
              phx-click="close_form"
              class="btn btn-ghost btn-sm btn-circle"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>
          <.live_component
            module={EventFormComponent}
            id={(@editing_event && @editing_event.id) || "new"}
            event={@editing_event}
            scope={@current_scope}
            prefill_date={@prefill_date}
            detached={@editing_as_detached}
          />

          <div :if={@editing_event && @editing_event.id} class="mt-4 pt-4 border-t border-base-200">
            <h4 class="font-medium text-sm mb-2">Linked Grocery Lists</h4>
            <div class="space-y-1">
              <%= if @grocery_lists == [] do %>
                <p class="text-xs text-base-content/50">No grocery lists</p>
              <% else %>
                <%= for list <- @grocery_lists do %>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      class="checkbox checkbox-sm"
                      checked={list.id in @linked_grocery_list_ids}
                      phx-click="toggle_grocery_link"
                      phx-value-list_id={list.id}
                    />
                    <span class="text-sm">{list.name}</span>
                  </label>
                <% end %>
              <% end %>
            </div>

            <div class="mt-4">
              <h4 class="font-medium text-sm mb-2">Linked Transactions</h4>
              <%= for tx <- linked_items(@linkable_transactions, @linked_transaction_ids) do %>
                <span class="badge badge-ghost gap-1 py-3 mb-1">
                  <span class="truncate max-w-48">
                    {tx.description || "No description"} &ndash; {format_amount(tx.amount)}
                  </span>
                  <button
                    phx-click="toggle_transaction_link"
                    phx-value-transaction_id={tx.id}
                    class="text-error"
                  >
                    <.icon name="hero-x-mark" class="size-3" />
                  </button>
                </span>
              <% end %>
              <%= if @linkable_transactions == [] do %>
                <p class="text-xs text-base-content/50">No transactions this month</p>
              <% else %>
                <% unlinked =
                  Enum.filter(@linkable_transactions, fn tx ->
                    tx.id not in @linked_transaction_ids
                  end) %>
                <%= if unlinked != [] do %>
                  <form phx-submit="toggle_transaction_link" class="join w-full mt-2">
                    <select name="transaction_id" class="select select-sm join-item flex-1">
                      <%= for tx <- unlinked do %>
                        <option value={tx.id}>
                          {tx.description || "No description"} &ndash; {format_amount(tx.amount)}
                        </option>
                      <% end %>
                    </select>
                    <button type="submit" class="btn btn-sm btn-primary join-item">Link</button>
                  </form>
                <% end %>
              <% end %>
            </div>

            <div :if={Accounts.feature_enabled?(@current_scope, "recipes")} class="mt-4">
              <h4 class="font-medium text-sm mb-2">Linked Recipes</h4>
              <%= for recipe <- linked_items(@linkable_recipes, @linked_recipe_ids) do %>
                <span class="badge badge-ghost gap-1 py-3 mb-1">
                  <span class="truncate max-w-48">{recipe.name}</span>
                  <button
                    phx-click="unlink_recipe"
                    phx-value-recipe_id={recipe.id}
                    class="text-error"
                  >
                    <.icon name="hero-x-mark" class="size-3" />
                  </button>
                </span>
              <% end %>
              <%= if @linkable_recipes == [] do %>
                <p class="text-xs text-base-content/50">No recipes</p>
              <% else %>
                <% unlinked_recipes =
                  Enum.filter(@linkable_recipes, fn r -> r.id not in @linked_recipe_ids end) %>
                <%= if unlinked_recipes != [] do %>
                  <form phx-submit="link_recipe" class="join w-full mt-2">
                    <select name="recipe_id" class="select select-sm join-item flex-1">
                      <%= for recipe <- unlinked_recipes do %>
                        <option value={recipe.id}>{recipe.name}</option>
                      <% end %>
                    </select>
                    <button type="submit" class="btn btn-sm btn-primary join-item">Link</button>
                  </form>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      <% else %>
        <div :if={@selected_date} class="p-5">
          <% events_map = events_by_date(@events) %>
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-semibold">
              {Calendar.strftime(@selected_date, "%A, %B %-d")}
            </h3>
            <button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle">
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>
          <% day_evts = Map.get(events_map, @selected_date, []) %>
          <%= if day_evts == [] do %>
            <.empty_state icon="hero-calendar" message="No events" />
          <% else %>
            <div class="space-y-1">
              <%= for event <- day_evts do %>
                <div class="flex items-start gap-1 rounded -mx-1 hover:bg-base-200/50">
                  <div
                    class="flex items-start gap-2 flex-1 min-w-0 cursor-pointer p-1"
                    phx-click={
                      if event.series_id, do: "show_recurrence_modal", else: "edit_event"
                    }
                    phx-value-id={event.id || event.series_id}
                    phx-value-series_id={event.series_id}
                    phx-value-occurrence_date={
                      event.series_id && Date.to_iso8601(DateTime.to_date(event.starts_at))
                    }
                  >
                    <div class={[
                      "w-2.5 h-2.5 rounded-full mt-1 shrink-0",
                      color_dot_class(event.color)
                    ]}>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium truncate">{event.title}</p>
                      <p class="text-xs text-base-content/60">{format_event_time(event)}</p>
                    </div>
                  </div>
                  <button
                    phx-click={
                      if event.series_id,
                        do: "show_recurrence_modal_delete",
                        else: "delete_event"
                    }
                    phx-value-id={event.id || event.series_id}
                    phx-value-series_id={event.series_id}
                    phx-value-occurrence_date={
                      event.series_id && Date.to_iso8601(DateTime.to_date(event.starts_at))
                    }
                    data-confirm={is_nil(event.series_id) && "Delete this event?"}
                    class="btn btn-ghost btn-xs text-error shrink-0 mt-0.5"
                  >
                    <.icon name="hero-trash" class="size-3" />
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
          <div class="mt-4 pt-3 border-t border-base-200">
            <button
              phx-click="new_event_on_date"
              phx-value-date={Date.to_iso8601(@selected_date)}
              class="btn btn-primary btn-sm w-full"
            >
              + Add Event
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # --- Private helpers ---

  defp load_month(socket, new_month) do
    weeks = calendar_weeks(new_month)
    {from_date, to_date} = date_range(weeks)
    events = Events.list_events_for_range(socket.assigns.current_scope, from_date, to_date)
    assign(socket, current_month: new_month, weeks: weeks, events: events)
  end

  defp reset_form(socket) do
    assign(socket,
      show_form: false,
      editing_event: nil,
      prefill_date: nil,
      editing_as_detached: nil,
      linked_grocery_list_ids: [],
      linked_transaction_ids: [],
      linkable_transactions: [],
      linked_recipe_ids: [],
      linkable_recipes: []
    )
  end

  defp reload_events(socket) do
    {from_date, to_date} = date_range(socket.assigns.weeks)
    events = Events.list_events_for_range(socket.assigns.current_scope, from_date, to_date)
    assign(socket, events: events)
  end

  defp calendar_weeks(month_date) do
    first_day = Date.new!(month_date.year, month_date.month, 1)
    # Elixir day_of_week: 1=Mon..7=Sun. Sunday-first offset: rem(7,7)=0, rem(1,7)=1 .. rem(6,7)=6
    offset = rem(Date.day_of_week(first_day), 7)
    start_date = Date.add(first_day, -offset)

    Enum.map(0..41, &Date.add(start_date, &1))
    |> Enum.chunk_every(7)
    |> Enum.filter(fn week -> Enum.any?(week, &(&1.month == month_date.month)) end)
  end

  defp date_range(weeks) do
    {weeks |> List.first() |> List.first(), weeks |> List.last() |> List.last()}
  end

  defp events_by_date(events) do
    Enum.group_by(events, &DateTime.to_date(&1.starts_at))
  end

  defp build_occurrence_for_modal(%Event{} = series, %Date{} = date) do
    time = DateTime.to_time(series.starts_at)
    occ_starts = DateTime.new!(date, time, "Etc/UTC")

    occ_ends =
      series.ends_at &&
        DateTime.add(
          occ_starts,
          DateTime.diff(series.ends_at, series.starts_at, :second),
          :second
        )

    %{
      series
      | id: nil,
        starts_at: occ_starts,
        ends_at: occ_ends,
        series_id: series.id,
        recurrence_type: "none",
        recurrence_interval: 1,
        recurrence_until: nil,
        recurrence_count: nil
    }
  end

  defp linked_items(all_items, linked_ids) do
    Enum.filter(all_items, fn item -> item.id in linked_ids end)
  end

  defp chip_class("blue"), do: "bg-info/15 border-info text-info"
  defp chip_class("green"), do: "bg-success/15 border-success text-success"
  defp chip_class("amber"), do: "bg-warning/20 border-warning text-warning-content"
  defp chip_class("rose"), do: "bg-error/15 border-error text-error"
  defp chip_class("purple"), do: "bg-purple-500/15 border-purple-500 text-purple-700"
  defp chip_class("slate"), do: "bg-slate-400/15 border-slate-400 text-slate-600"
  defp chip_class(_), do: "bg-info/15 border-info text-info"

  defp color_dot_class("blue"), do: "bg-info"
  defp color_dot_class("green"), do: "bg-success"
  defp color_dot_class("amber"), do: "bg-warning"
  defp color_dot_class("rose"), do: "bg-error"
  defp color_dot_class("purple"), do: "bg-purple-500"
  defp color_dot_class("slate"), do: "bg-slate-400"
  defp color_dot_class(_), do: "bg-info"

  defp format_chip_time(%Event{starts_at: starts_at}) do
    Calendar.strftime(starts_at, "%-I%p") |> String.downcase()
  end

  defp format_event_time(%Event{all_day: true}), do: "All day"

  defp format_event_time(%Event{starts_at: starts_at, ends_at: nil}) do
    Calendar.strftime(starts_at, "%-I:%M %p")
  end

  defp format_event_time(%Event{starts_at: starts_at, ends_at: ends_at}) do
    "#{Calendar.strftime(starts_at, "%-I:%M %p")} \u2013 #{Calendar.strftime(ends_at, "%-I:%M %p")}"
  end
end
