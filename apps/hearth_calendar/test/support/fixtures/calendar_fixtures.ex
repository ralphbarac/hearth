defmodule HearthCalendar.CalendarFixtures do
  alias HearthCalendar.Events

  def valid_event_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "title" => "Test Event #{System.unique_integer([:positive])}",
      "starts_at" => "2026-06-15T10:00:00Z",
      "color" => "blue"
    })
  end

  def event_fixture(scope, attrs \\ %{}) do
    {:ok, event} = Events.create_event(scope, valid_event_attributes(attrs))
    event
  end

  def recurring_event_fixture(scope, attrs \\ %{}) do
    base = %{
      "recurrence_type" => "weekly",
      "recurrence_interval" => "1"
    }

    {:ok, event} = Events.create_event(scope, valid_event_attributes(Map.merge(base, attrs)))
    event
  end
end
