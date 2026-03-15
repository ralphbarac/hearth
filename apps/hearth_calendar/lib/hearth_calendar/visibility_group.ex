defmodule HearthCalendar.VisibilityGroup do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "visibility_groups" do
    field(:name, :string)
    field(:color, :string, default: "blue")
    field(:is_default, :boolean, default: false)

    belongs_to(:household, Hearth.Households.Household)

    timestamps(type: :utc_datetime)
  end
end
