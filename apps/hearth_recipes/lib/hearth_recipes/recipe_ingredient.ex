defmodule HearthRecipes.RecipeIngredient do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "recipe_ingredients" do
    field :name, :string
    field :quantity, :string
    field :unit, :string
    field :position, :integer, default: 0

    belongs_to :recipe, HearthRecipes.Recipe

    timestamps(type: :utc_datetime)
  end

  def changeset(ingredient, attrs) do
    ingredient
    |> cast(attrs, [:name, :quantity, :unit, :position, :recipe_id])
    |> validate_required([:name, :recipe_id])
  end
end
