defmodule HearthRecipes.RecipesTest do
  use HearthRecipes.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthRecipes.RecipesFixtures

  alias HearthRecipes.Recipes
  alias HearthRecipes.Recipe

  describe "list_recipes/1" do
    test "returns empty list with no recipes" do
      scope = user_scope_fixture()
      assert Recipes.list_recipes(scope) == []
    end

    test "returns all recipes ordered by name with tags preloaded" do
      scope = user_scope_fixture()
      recipe_fixture(scope, %{"name" => "Zucchini Soup"})
      recipe_fixture(scope, %{"name" => "Apple Pie"})

      [r1, r2] = Recipes.list_recipes(scope)
      assert r1.name == "Apple Pie"
      assert r2.name == "Zucchini Soup"
      assert is_list(r1.tags)
    end

    test "isolates recipes by household" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      recipe_fixture(scope1, %{"name" => "Scope1 Recipe"})
      recipe_fixture(scope2, %{"name" => "Scope2 Recipe"})

      assert length(Recipes.list_recipes(scope1)) == 1
      assert hd(Recipes.list_recipes(scope1)).name == "Scope1 Recipe"
    end
  end

  describe "list_recipes_by_tag/2" do
    test "filters recipes by tag" do
      scope = user_scope_fixture()
      tag = tag_fixture(scope, %{"name" => "Vegan"})
      recipe1 = recipe_fixture(scope, %{"name" => "Salad"})
      recipe_fixture(scope, %{"name" => "Steak"})
      Recipes.set_tags(scope, recipe1, [tag.id])

      results = Recipes.list_recipes_by_tag(scope, tag.id)
      assert length(results) == 1
      assert hd(results).name == "Salad"
    end

    test "returns empty list if no recipes match" do
      scope = user_scope_fixture()
      tag = tag_fixture(scope)
      assert Recipes.list_recipes_by_tag(scope, tag.id) == []
    end
  end

  describe "create_recipe/2" do
    test "creates recipe with valid attrs" do
      scope = user_scope_fixture()
      attrs = %{"name" => "Pasta", "servings" => 4, "prep_time_minutes" => 10}
      assert {:ok, %Recipe{} = recipe} = Recipes.create_recipe(scope, attrs)
      assert recipe.name == "Pasta"
      assert recipe.servings == 4
      assert recipe.household_id == scope.household.id
      assert recipe.created_by_id == scope.user.id
    end

    test "returns error when name is missing" do
      scope = user_scope_fixture()
      assert {:error, changeset} = Recipes.create_recipe(scope, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "creates recipe with optional fields nil" do
      scope = user_scope_fixture()
      {:ok, recipe} = Recipes.create_recipe(scope, %{"name" => "Simple"})
      assert is_nil(recipe.description)
      assert is_nil(recipe.servings)
    end
  end

  describe "update_recipe/3" do
    test "updates fields" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope, %{"name" => "Old Name"})
      assert {:ok, updated} = Recipes.update_recipe(scope, recipe, %{"name" => "New Name", "servings" => 2})
      assert updated.name == "New Name"
      assert updated.servings == 2
    end

    test "returns error with invalid attrs" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      assert {:error, changeset} = Recipes.update_recipe(scope, recipe, %{"name" => ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_recipe/2" do
    test "removes recipe" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      assert {:ok, _} = Recipes.delete_recipe(scope, recipe)
      assert Recipes.list_recipes(scope) == []
    end

    test "cascades to ingredients and steps" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      ingredient_fixture(scope, recipe)
      step_fixture(scope, recipe, %{"step_number" => 1})

      assert {:ok, _} = Recipes.delete_recipe(scope, recipe)
      assert Recipes.list_recipes(scope) == []
    end
  end

  describe "get_recipe!/2" do
    test "returns recipe with preloads" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      ingredient_fixture(scope, recipe, %{"name" => "Flour"})
      step_fixture(scope, recipe, %{"step_number" => 1, "description" => "Mix"})

      found = Recipes.get_recipe!(scope, recipe.id)
      assert found.id == recipe.id
      assert length(found.ingredients) == 1
      assert hd(found.ingredients).name == "Flour"
      assert length(found.steps) == 1
      assert hd(found.steps).description == "Mix"
      assert is_list(found.tags)
    end

    test "raises for recipe from another household" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      recipe = recipe_fixture(scope1)

      assert_raise Ecto.NoResultsError, fn ->
        Recipes.get_recipe!(scope2, recipe.id)
      end
    end
  end

  describe "set_tags/3" do
    test "assigns tags to recipe" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      tag = tag_fixture(scope, %{"name" => "Italian"})

      {:ok, updated} = Recipes.set_tags(scope, recipe, [tag.id])
      assert length(updated.tags) == 1
      assert hd(updated.tags).id == tag.id
    end

    test "replaces all tags" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      tag1 = tag_fixture(scope, %{"name" => "Italian"})
      tag2 = tag_fixture(scope, %{"name" => "Vegan"})

      Recipes.set_tags(scope, recipe, [tag1.id])
      recipe_with_tag1 = Recipes.get_recipe!(scope, recipe.id)
      assert length(recipe_with_tag1.tags) == 1

      Recipes.set_tags(scope, recipe_with_tag1, [tag2.id])
      recipe_with_tag2 = Recipes.get_recipe!(scope, recipe.id)
      assert length(recipe_with_tag2.tags) == 1
      assert hd(recipe_with_tag2.tags).id == tag2.id
    end

    test "empty list clears all tags" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      tag = tag_fixture(scope)
      Recipes.set_tags(scope, recipe, [tag.id])
      recipe_with_tag = Recipes.get_recipe!(scope, recipe.id)

      {:ok, _} = Recipes.set_tags(scope, recipe_with_tag, [])
      recipe_cleared = Recipes.get_recipe!(scope, recipe.id)
      assert recipe_cleared.tags == []
    end
  end

  describe "add_ingredient/3" do
    test "creates ingredient with auto position" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      {:ok, i1} = Recipes.add_ingredient(scope, recipe, %{"name" => "Flour"})
      {:ok, i2} = Recipes.add_ingredient(scope, recipe, %{"name" => "Sugar"})
      assert i1.position == 0
      assert i2.position == 1
    end

    test "validates name required" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      assert {:error, changeset} = Recipes.add_ingredient(scope, recipe, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_ingredient/3" do
    test "updates ingredient" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      ingredient = ingredient_fixture(scope, recipe, %{"name" => "Old"})
      assert {:ok, updated} = Recipes.update_ingredient(scope, ingredient, %{"name" => "New"})
      assert updated.name == "New"
    end

    test "validates name required" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      ingredient = ingredient_fixture(scope, recipe)
      assert {:error, _} = Recipes.update_ingredient(scope, ingredient, %{"name" => ""})
    end
  end

  describe "delete_ingredient/2" do
    test "removes ingredient" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      ingredient = ingredient_fixture(scope, recipe)
      assert {:ok, _} = Recipes.delete_ingredient(scope, ingredient)
      found = Recipes.get_recipe!(scope, recipe.id)
      assert found.ingredients == []
    end
  end

  describe "add_step/3" do
    test "creates step with step_number" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      {:ok, step} = Recipes.add_step(scope, recipe, %{"step_number" => 1, "description" => "Mix well"})
      assert step.step_number == 1
      assert step.description == "Mix well"
    end
  end

  describe "update_step/3" do
    test "updates step" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      step = step_fixture(scope, recipe, %{"step_number" => 1, "description" => "Old"})
      assert {:ok, updated} = Recipes.update_step(scope, step, %{"description" => "New"})
      assert updated.description == "New"
    end
  end

  describe "delete_step/2" do
    test "removes step" do
      scope = user_scope_fixture()
      recipe = recipe_fixture(scope)
      step = step_fixture(scope, recipe, %{"step_number" => 1})
      assert {:ok, _} = Recipes.delete_step(scope, step)
      found = Recipes.get_recipe!(scope, recipe.id)
      assert found.steps == []
    end
  end
end
