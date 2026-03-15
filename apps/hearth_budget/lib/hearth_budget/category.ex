defmodule HearthBudget.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(income expense)

  schema "budget_categories" do
    field(:name, :string)
    field(:icon, :string)
    field(:type, :string)
    field(:is_default, :boolean, default: false)

    belongs_to(:household, Hearth.Households.Household)

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :icon, :type, :is_default, :household_id])
    |> validate_required([:name, :type, :household_id])
    |> validate_inclusion(:type, @types)
  end
end
