defmodule HearthRecipes.RecipesFixtures do
  alias HearthRecipes.{Tags, Recipes}

  def valid_tag_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "tag-#{System.unique_integer([:positive])}"
    })
  end

  def tag_fixture(scope, attrs \\ %{}) do
    {:ok, tag} = Tags.create_tag(scope, valid_tag_attributes(attrs))
    tag
  end

  def valid_recipe_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Recipe #{System.unique_integer([:positive])}"
    })
  end

  def recipe_fixture(scope, attrs \\ %{}) do
    {:ok, recipe} = Recipes.create_recipe(scope, valid_recipe_attributes(attrs))
    recipe
  end

  def ingredient_fixture(scope, recipe, attrs \\ %{}) do
    {:ok, ingredient} =
      Recipes.add_ingredient(scope, recipe, Map.merge(%{"name" => "Ingredient #{System.unique_integer([:positive])}"}, attrs))

    ingredient
  end

  def step_fixture(scope, recipe, attrs \\ %{}) do
    step_number = Map.get(attrs, "step_number", System.unique_integer([:positive]))

    {:ok, step} =
      Recipes.add_step(scope, recipe, Map.merge(%{"step_number" => step_number, "description" => "Do something"}, attrs))

    step
  end
end
