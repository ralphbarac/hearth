defmodule HearthCalendar.EventsTest do
  use HearthCalendar.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthCalendar.CalendarFixtures

  alias HearthCalendar.Events
  alias HearthCalendar.Event

  describe "list_events/1" do
    test "returns empty list with no events" do
      scope = user_scope_fixture()
      assert Events.list_events(scope) == []
    end

    test "returns only own household's events" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      event1 = event_fixture(scope1, %{"title" => "Event A"})
      _event2 = event_fixture(scope2, %{"title" => "Event B"})

      results = Events.list_events(scope1)
      assert length(results) == 1
      assert hd(results).id == event1.id
    end

    test "returns events ordered by starts_at" do
      scope = user_scope_fixture()

      _later = event_fixture(scope, %{"title" => "Later", "starts_at" => "2026-06-20T10:00:00Z"})

      _earlier =
        event_fixture(scope, %{"title" => "Earlier", "starts_at" => "2026-06-10T10:00:00Z"})

      [first, second] = Events.list_events(scope)
      assert first.title == "Earlier"
      assert second.title == "Later"
    end
  end

  describe "create_event/2" do
    test "creates event with valid attrs" do
      scope = user_scope_fixture()
      attrs = valid_event_attributes(%{"title" => "My Event"})

      assert {:ok, %Event{} = event} = Events.create_event(scope, attrs)
      assert event.title == "My Event"
      assert event.household_id == scope.household.id
      assert event.created_by_id == scope.user.id
    end

    test "returns error with blank attrs" do
      scope = user_scope_fixture()
      assert {:error, changeset} = Events.create_event(scope, %{})
      assert %{title: ["can't be blank"], starts_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error when ends_at is before starts_at" do
      scope = user_scope_fixture()

      attrs =
        valid_event_attributes(%{
          "starts_at" => "2026-06-15T10:00:00Z",
          "ends_at" => "2026-06-15T09:00:00Z"
        })

      assert {:error, changeset} = Events.create_event(scope, attrs)
      assert %{ends_at: ["must be after start time"]} = errors_on(changeset)
    end
  end

  describe "update_event/3" do
    test "updates event with valid attrs" do
      scope = user_scope_fixture()
      event = event_fixture(scope)

      assert {:ok, updated} = Events.update_event(scope, event, %{"title" => "Updated Title"})
      assert updated.title == "Updated Title"
    end

    test "returns error with invalid attrs" do
      scope = user_scope_fixture()
      event = event_fixture(scope)

      assert {:error, changeset} = Events.update_event(scope, event, %{"title" => ""})
      assert %{title: [_ | _]} = errors_on(changeset)
    end
  end

  describe "delete_event/2" do
    test "removes event from list" do
      scope = user_scope_fixture()
      event = event_fixture(scope)

      assert {:ok, _} = Events.delete_event(scope, event)
      assert Events.list_events(scope) == []
    end
  end

  describe "recurring events" do
    test "daily series expands occurrences within range" do
      scope = user_scope_fixture()

      event_fixture(scope, %{
        "starts_at" => "2026-06-01T10:00:00Z",
        "recurrence_type" => "daily",
        "recurrence_interval" => "1",
        "recurrence_count" => "10"
      })

      events = Events.list_events_for_range(scope, ~D[2026-06-03], ~D[2026-06-05])
      assert length(events) == 3
      dates = Enum.map(events, &DateTime.to_date(&1.starts_at))
      assert ~D[2026-06-03] in dates
      assert ~D[2026-06-04] in dates
      assert ~D[2026-06-05] in dates
    end

    test "respects recurrence_until boundary" do
      scope = user_scope_fixture()

      event_fixture(scope, %{
        "starts_at" => "2026-06-01T10:00:00Z",
        "recurrence_type" => "daily",
        "recurrence_interval" => "1",
        "recurrence_until" => "2026-06-03"
      })

      events = Events.list_events_for_range(scope, ~D[2026-06-01], ~D[2026-06-10])
      assert length(events) == 3
      dates = Enum.map(events, &DateTime.to_date(&1.starts_at))
      assert ~D[2026-06-01] in dates
      assert ~D[2026-06-03] in dates
      refute ~D[2026-06-04] in dates
    end

    test "monthly recurrence handles month overflow (Jan 31 -> Feb 28)" do
      scope = user_scope_fixture()

      event_fixture(scope, %{
        "starts_at" => "2026-01-31T10:00:00Z",
        "recurrence_type" => "monthly",
        "recurrence_interval" => "1",
        "recurrence_count" => "3"
      })

      events = Events.list_events_for_range(scope, ~D[2026-02-01], ~D[2026-03-31])
      assert length(events) == 2
      dates = Enum.map(events, &DateTime.to_date(&1.starts_at))
      assert ~D[2026-02-28] in dates
      # Date.shift shifts from the actual stored date (Feb 28), so next is Mar 28
      assert ~D[2026-03-28] in dates
    end

    test "weekly recurrence spans multiple weeks" do
      scope = user_scope_fixture()

      event_fixture(scope, %{
        "starts_at" => "2026-06-01T10:00:00Z",
        "recurrence_type" => "weekly",
        "recurrence_interval" => "1",
        "recurrence_count" => "4"
      })

      events = Events.list_events_for_range(scope, ~D[2026-06-01], ~D[2026-06-30])
      assert length(events) == 4
    end

    test "exception dates are excluded from expansion" do
      scope = user_scope_fixture()

      series =
        event_fixture(scope, %{
          "starts_at" => "2026-06-01T10:00:00Z",
          "recurrence_type" => "daily",
          "recurrence_interval" => "1",
          "recurrence_count" => "5"
        })

      {:ok, _} = Events.add_exception(scope, series, ~D[2026-06-03])

      events = Events.list_events_for_range(scope, ~D[2026-06-01], ~D[2026-06-05])
      dates = Enum.map(events, &DateTime.to_date(&1.starts_at))
      refute ~D[2026-06-03] in dates
      assert length(events) == 4
    end

    test "create_detached_occurrence creates new event and exception" do
      scope = user_scope_fixture()

      series =
        event_fixture(scope, %{
          "starts_at" => "2026-06-01T10:00:00Z",
          "recurrence_type" => "daily",
          "recurrence_interval" => "1",
          "recurrence_count" => "5"
        })

      attrs = %{"title" => "Detached Occurrence", "starts_at" => "2026-06-03T14:00:00Z"}

      assert {:ok, detached} =
               Events.create_detached_occurrence(scope, series, attrs, ~D[2026-06-03])

      assert detached.title == "Detached Occurrence"
      assert detached.recurrence_parent_id == series.id
      assert detached.recurrence_type == "none"

      # June 3 should no longer appear from series expansion
      events = Events.list_events_for_range(scope, ~D[2026-06-01], ~D[2026-06-05])

      series_occurrence_dates =
        events
        |> Enum.filter(&(&1.series_id == series.id))
        |> Enum.map(&DateTime.to_date(&1.starts_at))

      refute ~D[2026-06-03] in series_occurrence_dates

      # But the detached event appears on June 3 (at 14:00)
      all_dates = Enum.map(events, &DateTime.to_date(&1.starts_at))
      assert ~D[2026-06-03] in all_dates
    end

    test "household isolation: series events don't leak across households" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      event_fixture(scope1, %{
        "starts_at" => "2026-06-01T10:00:00Z",
        "recurrence_type" => "daily",
        "recurrence_interval" => "1",
        "recurrence_count" => "5"
      })

      events = Events.list_events_for_range(scope2, ~D[2026-06-01], ~D[2026-06-05])
      assert events == []
    end
  end

  describe "get_event!/2" do
    test "returns own event" do
      scope = user_scope_fixture()
      event = event_fixture(scope)

      assert fetched = Events.get_event!(scope, event.id)
      assert fetched.id == event.id
    end

    test "raises for another household's event" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      event = event_fixture(scope1)

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_event!(scope2, event.id)
      end
    end
  end
end
