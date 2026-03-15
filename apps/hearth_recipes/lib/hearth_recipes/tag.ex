defmodule HearthRecipes.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "recipe_tags" do
    field :name, :string

    belongs_to :household, Hearth.Households.Household

    timestamps(type: :utc_datetime)
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :household_id])
    |> validate_required([:name])
    |> validate_length(:name, max: 50)
    |> unique_constraint([:household_id, :name])
  end
end
