defmodule HearthCalendar.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @colors ~w(blue green amber rose purple slate)

  schema "calendar_events" do
    field(:title, :string)
    field(:description, :string)
    field(:starts_at, :utc_datetime)
    field(:ends_at, :utc_datetime)
    field(:all_day, :boolean, default: false)
    field(:color, :string, default: "blue")
    field(:location, :string)
    field(:recurrence_rule, :string)

    field(:recurrence_type, :string, default: "none")
    field(:recurrence_interval, :integer, default: 1)
    field(:recurrence_until, :date)
    field(:recurrence_count, :integer)
    field(:series_id, :string, virtual: true)

    belongs_to(:household, Hearth.Households.Household)
    belongs_to(:created_by, Hearth.Accounts.User)
    belongs_to(:recurrence_parent, __MODULE__)
    has_many(:exceptions, HearthCalendar.EventException)

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    attrs = normalize_datetime_strings(attrs)

    event
    |> cast(attrs, [
      :title,
      :description,
      :starts_at,
      :ends_at,
      :all_day,
      :color,
      :location,
      :recurrence_rule,
      :household_id,
      :created_by_id,
      :recurrence_type,
      :recurrence_interval,
      :recurrence_until,
      :recurrence_count,
      :recurrence_parent_id
    ])
    |> validate_required([:title, :starts_at, :household_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:color, @colors)
    |> validate_inclusion(:recurrence_type, ~w(none daily weekly monthly yearly))
    |> validate_number(:recurrence_interval, greater_than: 0)
    |> validate_ends_after_starts()
  end

  defp normalize_datetime_strings(attrs) when is_map(attrs) do
    attrs
    |> maybe_normalize_dt("starts_at")
    |> maybe_normalize_dt("ends_at")
    |> maybe_normalize_dt(:starts_at)
    |> maybe_normalize_dt(:ends_at)
  end

  defp maybe_normalize_dt(attrs, key) do
    case Map.get(attrs, key) do
      val when is_binary(val) and byte_size(val) == 16 ->
        Map.put(attrs, key, val <> ":00")

      _ ->
        attrs
    end
  end

  defp validate_ends_after_starts(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(ends_at, starts_at) == :lt do
      add_error(changeset, :ends_at, "must be after start time")
    else
      changeset
    end
  end
end
