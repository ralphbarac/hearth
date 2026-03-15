defmodule HearthRecipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "recipes" do
    field :name, :string
    field :description, :string
    field :servings, :integer
    field :prep_time_minutes, :integer
    field :cook_time_minutes, :integer
    field :notes, :string

    belongs_to :household, Hearth.Households.Household
    belongs_to :created_by, Hearth.Accounts.User

    has_many :ingredients, HearthRecipes.RecipeIngredient, on_replace: :delete
    has_many :steps, HearthRecipes.RecipeStep, on_replace: :delete
    many_to_many :tags, HearthRecipes.Tag, join_through: "recipes_to_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [
      :name,
      :description,
      :servings,
      :prep_time_minutes,
      :cook_time_minutes,
      :notes,
      :household_id,
      :created_by_id
    ])
    |> validate_required([:name])
    |> validate_length(:name, max: 200)
  end
end
