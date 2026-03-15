defmodule HearthWeb.RecipesFixtures do
  alias HearthRecipes.{Recipes, Tags}

  def valid_recipe_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Recipe #{System.unique_integer([:positive])}"
    })
  end

  def recipe_fixture(scope, attrs \\ %{}) do
    {:ok, recipe} = Recipes.create_recipe(scope, valid_recipe_attributes(attrs))
    recipe
  end

  def tag_fixture(scope, attrs \\ %{}) do
    name = Map.get(attrs, "name", "tag-#{System.unique_integer([:positive])}")
    {:ok, tag} = Tags.create_tag(scope, %{"name" => name})
    tag
  end
end
