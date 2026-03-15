defmodule HearthInventory.InventoryItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_items" do
    field :name, :string
    field :unit, :string
    field :quantity, :integer, default: 0
    field :min_quantity, :integer, default: 0
    field :category, :string
    field :notes, :string

    belongs_to :household, Hearth.Households.Household
    belongs_to :created_by, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :unit, :quantity, :min_quantity, :category, :notes, :household_id, :created_by_id])
    |> validate_required([:name])
    |> validate_length(:name, max: 200)
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> validate_number(:min_quantity, greater_than_or_equal_to: 0)
  end
end
