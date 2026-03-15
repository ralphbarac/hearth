defmodule HearthWeb.CalendarLive.EventFormComponent do
  use HearthWeb, :live_component

  alias HearthCalendar.Events
  alias HearthCalendar.Event

  @impl true
  def update(%{event: event, scope: scope} = assigns, socket) do
    prefill_date = Map.get(assigns, :prefill_date)
    detached = Map.get(assigns, :detached)

    changeset =
      if is_nil(event.id) and prefill_date do
        starts_at_str = Calendar.strftime(prefill_date, "%Y-%m-%dT09:00")
        Event.changeset(event, %{"starts_at" => starts_at_str})
      else
        Event.changeset(event, %{})
      end

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:event, event)
     |> assign(:detached, detached)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"event" => params}, socket) do
    changeset =
      socket.assigns.event
      |> Event.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"event" => params}, socket) do
    save_event(socket, socket.assigns.event.id, params)
  end

  defp save_event(socket, nil, params) do
    case socket.assigns.detached do
      {series_id, occurrence_date} ->
        scope = socket.assigns.scope
        parent = Events.get_event!(scope, series_id)

        case Events.create_detached_occurrence(scope, parent, params, occurrence_date) do
          {:ok, event} ->
            send(self(), {__MODULE__, :saved, event})
            {:noreply, socket}

          {:error, changeset} ->
            {:noreply, assign_form(socket, changeset)}
        end

      _ ->
        case Events.create_event(socket.assigns.scope, params) do
          {:ok, event} ->
            send(self(), {__MODULE__, :saved, event})
            {:noreply, socket}

          {:error, changeset} ->
            {:noreply, assign_form(socket, changeset)}
        end
    end
  end

  defp save_event(socket, _id, params) do
    case Events.update_event(socket.assigns.scope, socket.assigns.event, params) do
      {:ok, event} ->
        send(self(), {__MODULE__, :saved, event})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "event"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:starts_at]} type="datetime-local" label="Starts at" />
        <.input field={@form[:ends_at]} type="datetime-local" label="Ends at" />
        <.input
          field={@form[:color]}
          type="select"
          label="Color"
          options={[
            Blue: "blue",
            Green: "green",
            Amber: "amber",
            Rose: "rose",
            Purple: "purple",
            Slate: "slate"
          ]}
        />
        <.input field={@form[:location]} type="text" label="Location" />
        <.input field={@form[:all_day]} type="checkbox" label="All day" />
        <.input
          field={@form[:recurrence_type]}
          type="select"
          label="Repeat"
          options={[
            {"Does not repeat", "none"},
            {"Daily", "daily"},
            {"Weekly", "weekly"},
            {"Monthly", "monthly"},
            {"Yearly", "yearly"}
          ]}
        />
        <div :if={@form[:recurrence_type].value not in [nil, "none", ""]}>
          <.input field={@form[:recurrence_interval]} type="number" label="Repeat every" min="1" />
          <.input field={@form[:recurrence_until]} type="date" label="Until" />
        </div>
        <div class="mt-4">
          <.button type="submit" variant="primary" phx-disable-with="Saving...">Save Event</.button>
        </div>
      </.form>
    </div>
    """
  end
end
