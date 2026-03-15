defmodule HearthGrocery.GroceryItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "grocery_items" do
    field(:name, :string)
    field(:quantity, :string)
    field(:category, :string)
    field(:checked, :boolean, default: false)
    field(:position, :integer, default: 0)

    belongs_to(:list, HearthGrocery.GroceryList)
    belongs_to(:added_by, Hearth.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :quantity, :category, :checked, :position, :list_id, :added_by_id])
    |> validate_required([:name])
    |> validate_length(:name, max: 200)
  end
end
