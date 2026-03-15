defmodule HearthWeb.CalendarFixtures do
  alias HearthCalendar.Events

  def valid_event_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "title" => "Test Event #{System.unique_integer([:positive])}",
      "starts_at" => current_month_starts_at(),
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
      "recurrence_interval" => "1",
      "starts_at" => first_of_current_month_starts_at()
    }

    {:ok, event} = Events.create_event(scope, valid_event_attributes(Map.merge(base, attrs)))
    event
  end

  defp first_of_current_month_starts_at do
    today = Date.utc_today()
    day1 = %{today | day: 1}
    DateTime.new!(day1, ~T[10:00:00], "Etc/UTC") |> DateTime.to_iso8601()
  end

  defp current_month_starts_at do
    today = Date.utc_today()
    day15 = %{today | day: 15}
    DateTime.new!(day15, ~T[10:00:00], "Etc/UTC") |> DateTime.to_iso8601()
  end
end
