defmodule HearthGrocery.GroceryList do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "grocery_lists" do
    field(:name, :string)
    field(:notes, :string)
    field(:is_active, :boolean, default: true)

    belongs_to(:household, Hearth.Households.Household)
    belongs_to(:created_by, Hearth.Accounts.User)
    has_many(:items, HearthGrocery.GroceryItem, foreign_key: :list_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :notes, :is_active, :household_id, :created_by_id])
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
  end
end
