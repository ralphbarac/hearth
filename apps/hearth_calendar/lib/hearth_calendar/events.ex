defmodule HearthCalendar.Events do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthCalendar.Event
  alias HearthCalendar.EventException

  @pubsub Hearth.PubSub
  @topic_prefix "household"
  @topic_suffix "calendar"

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_events(%Scope{household: household}) do
    Event
    |> where([e], e.household_id == ^household.id)
    |> order_by([e], asc: e.starts_at)
    |> Repo.all()
  end

  def list_events_for_range(%Scope{household: household}, from_date, to_date) do
    from_dt = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to_dt = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")

    regular =
      from(e in Event,
        where: e.household_id == ^household.id,
        where: e.recurrence_type == "none",
        where: e.starts_at >= ^from_dt and e.starts_at <= ^to_dt
      )
      |> Repo.all()

    series =
      from(e in Event,
        where: e.household_id == ^household.id,
        where: e.recurrence_type != "none",
        where: is_nil(e.recurrence_parent_id),
        where: e.starts_at <= ^to_dt,
        where: is_nil(e.recurrence_until) or e.recurrence_until >= ^from_date,
        preload: :exceptions
      )
      |> Repo.all()

    (regular ++ Enum.flat_map(series, &expand_occurrences(&1, from_date, to_date)))
    |> Enum.sort_by(&DateTime.to_unix(&1.starts_at))
  end

  def list_upcoming_events(%Scope{household: household}, limit \\ 50) do
    now = DateTime.utc_now()

    Event
    |> where([e], e.household_id == ^household.id and e.starts_at >= ^now)
    |> order_by([e], asc: e.starts_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_event!(%Scope{household: household}, id) do
    Event
    |> where([e], e.household_id == ^household.id and e.id == ^id)
    |> Repo.one!()
  end

  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  def create_event(%Scope{household: household, user: user}, attrs) do
    %Event{}
    |> Event.changeset(
      Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id})
    )
    |> Repo.insert()
    |> tap_broadcast(:created, household.id)
  end

  def update_event(%Scope{}, %Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, event.household_id)
  end

  def delete_event(%Scope{}, %Event{} = event) do
    Repo.delete(event)
    |> tap_broadcast(:deleted, event.household_id)
  end

  def add_exception(%Scope{}, %Event{} = series, %Date{} = date) do
    %EventException{}
    |> EventException.changeset(%{event_id: series.id, excluded_date: date})
    |> Repo.insert()
  end

  def create_detached_occurrence(
        %Scope{household: household, user: user},
        %Event{} = parent,
        attrs,
        %Date{} = occurrence_date
      ) do
    merged_attrs =
      Map.merge(attrs, %{
        "household_id" => household.id,
        "created_by_id" => user.id,
        "recurrence_parent_id" => parent.id,
        "recurrence_type" => "none"
      })

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:new_event, Event.changeset(%Event{}, merged_attrs))
    |> Ecto.Multi.insert(
      :exception,
      EventException.changeset(%EventException{}, %{
        event_id: parent.id,
        excluded_date: occurrence_date
      })
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{new_event: event}} ->
        tap_broadcast({:ok, event}, :created, household.id)

      {:error, :new_event, changeset, _} ->
        {:error, changeset}

      {:error, :exception, _changeset, _} ->
        {:error, Event.changeset(%Event{}, attrs)}
    end
  end

  # --- Private helpers ---

  defp expand_occurrences(%Event{} = series, from_date, to_date) do
    excluded = MapSet.new(series.exceptions, & &1.excluded_date)
    start_date = DateTime.to_date(series.starts_at)

    start_date
    |> Stream.iterate(
      &next_occurrence_date(&1, series.recurrence_type, series.recurrence_interval)
    )
    |> Stream.with_index(1)
    |> Stream.take_while(fn {date, idx} ->
      count_ok = is_nil(series.recurrence_count) or idx <= series.recurrence_count

      until_ok =
        is_nil(series.recurrence_until) or Date.compare(date, series.recurrence_until) != :gt

      date_ok = Date.compare(date, to_date) != :gt
      count_ok and until_ok and date_ok
    end)
    |> Stream.filter(fn {date, _} ->
      Date.compare(date, from_date) != :lt and date not in excluded
    end)
    |> Enum.map(fn {date, _} -> build_occurrence(series, date) end)
  end

  defp next_occurrence_date(date, "daily", i), do: Date.add(date, i)
  defp next_occurrence_date(date, "weekly", i), do: Date.add(date, i * 7)
  defp next_occurrence_date(date, "monthly", i), do: Date.shift(date, month: i)
  defp next_occurrence_date(date, "yearly", i), do: Date.shift(date, year: i)

  defp build_occurrence(%Event{} = series, date) do
    time = DateTime.to_time(series.starts_at)
    occ_starts = DateTime.new!(date, time, "Etc/UTC")

    occ_ends =
      series.ends_at &&
        DateTime.add(
          occ_starts,
          DateTime.diff(series.ends_at, series.starts_at, :second),
          :second
        )

    %{series | id: nil, starts_at: occ_starts, ends_at: occ_ends, series_id: series.id}
  end

  defp topic(household_id), do: "#{@topic_prefix}:#{household_id}:#{@topic_suffix}"

  defp tap_broadcast({:ok, event} = result, action, household_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, event})
    result
  end

  defp tap_broadcast(error, _action, _household_id), do: error
end
