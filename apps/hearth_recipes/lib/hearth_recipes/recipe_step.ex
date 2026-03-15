defmodule HearthRecipes.RecipeStep do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "recipe_steps" do
    field :step_number, :integer
    field :description, :string

    belongs_to :recipe, HearthRecipes.Recipe

    timestamps(type: :utc_datetime)
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:step_number, :description, :recipe_id])
    |> validate_required([:step_number, :description, :recipe_id])
    |> unique_constraint([:recipe_id, :step_number])
  end
end
