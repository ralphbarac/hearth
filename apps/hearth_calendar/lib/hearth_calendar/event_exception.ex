defmodule HearthCalendar.EventException do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "calendar_event_exceptions" do
    belongs_to(:event, HearthCalendar.Event)
    field(:excluded_date, :date)

    timestamps(type: :utc_datetime)
  end

  def changeset(exception, attrs) do
    exception
    |> cast(attrs, [:event_id, :excluded_date])
    |> validate_required([:event_id, :excluded_date])
    |> unique_constraint(:excluded_date,
      name: :calendar_event_exceptions_event_id_excluded_date_index
    )
  end
end
