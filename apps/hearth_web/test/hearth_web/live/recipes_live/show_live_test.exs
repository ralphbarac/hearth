defmodule HearthWeb.RecipesLive.ShowTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.RecipesFixtures

  alias Hearth.Households
  alias HearthRecipes.Recipes

  describe "feature disabled" do
    setup :register_and_log_in_user

    test "redirects to dashboard when feature disabled", %{conn: conn, scope: scope} do
      {:ok, recipe} = Recipes.create_recipe(scope, %{"name" => "Test"})
      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/recipes/#{recipe.id}")
    end
  end

  describe "Show page" do
    setup [:register_and_log_in_user, :enable_recipes]

    test "shows recipe details", %{conn: conn, scope: scope} do
      {:ok, recipe} =
        Recipes.create_recipe(scope, %{
          "name" => "Carbonara",
          "description" => "Classic Italian pasta",
          "servings" => 2,
          "prep_time_minutes" => 15,
          "cook_time_minutes" => 20
        })

      {:ok, _view, html} = live(conn, ~p"/recipes/#{recipe.id}")
      assert html =~ "Carbonara"
      assert html =~ "Classic Italian pasta"
      assert html =~ "Prep: 15m"
      assert html =~ "Cook: 20m"
    end

    test "shows empty ingredients and steps sections", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope)
      {:ok, _view, html} = live(conn, ~p"/recipes/#{recipe.id}")
      assert html =~ "Ingredients"
      assert html =~ "Steps"
      assert html =~ "No ingredients yet"
      assert html =~ "No steps yet"
    end

    test "adds ingredient inline", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}")

      view |> element("[phx-click='add_ingredient']") |> render_click()

      view
      |> form("form[phx-submit='save_new_ingredient']", %{name: "Eggs", quantity: "3"})
      |> render_submit()

      assert render(view) =~ "Eggs"
    end

    test "deletes ingredient", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope)
      {:ok, ingredient} = Recipes.add_ingredient(scope, recipe, %{"name" => "Butter"})

      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}")
      assert render(view) =~ "Butter"

      view
      |> element("[phx-click='delete_ingredient'][phx-value-id='#{ingredient.id}']")
      |> render_click()

      refute render(view) =~ "Butter"
    end

    test "adds step inline", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}")

      view |> element("[phx-click='add_step']") |> render_click()

      view
      |> form("form[phx-submit='save_new_step']", %{description: "Preheat oven to 350"})
      |> render_submit()

      assert render(view) =~ "Preheat oven to 350"
    end

    test "deletes step", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope)

      {:ok, step} =
        Recipes.add_step(scope, recipe, %{"step_number" => 1, "description" => "Boil water"})

      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}")
      assert render(view) =~ "Boil water"

      view
      |> element("[phx-click='delete_step'][phx-value-id='#{step.id}']")
      |> render_click()

      refute render(view) =~ "Boil water"
    end

    test "edits recipe via form", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope, %{"name" => "Original Name"})
      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}")

      view |> element("button", "Edit") |> render_click()

      view
      |> form("form", recipe: %{name: "Updated Name"})
      |> render_submit()

      assert render(view) =~ "Updated Name"
    end
  end

  describe "grocery integration" do
    setup [:register_and_log_in_user, :enable_recipes, :enable_grocery]

    test "shows Add to Grocery List button when grocery enabled", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope)
      {:ok, _} = Recipes.add_ingredient(scope, recipe, %{"name" => "Flour"})
      {:ok, _} = HearthGrocery.GroceryLists.create_grocery_list(scope, %{"name" => "Shopping"})

      {:ok, _view, html} = live(conn, ~p"/recipes/#{recipe.id}")
      assert html =~ "Add to Grocery List"
    end

    test "adds ingredients to grocery list", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope, %{"name" => "Cookies"})
      {:ok, _} = Recipes.add_ingredient(scope, recipe, %{"name" => "Flour"})
      {:ok, list} = HearthGrocery.GroceryLists.create_grocery_list(scope, %{"name" => "Shopping"})

      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}")

      view |> element("[phx-click='show_grocery_modal']") |> render_click()
      assert render(view) =~ "Add Ingredients to Grocery List"

      view |> element("button", "Add to List") |> render_click()
      assert render(view) =~ "Ingredients added to"

      items = HearthGrocery.GroceryItems.list_items(scope, list)
      assert Enum.any?(items, &(&1.name == "Flour"))
    end
  end

  defp enable_recipes(%{scope: scope} = ctx) do
    {:ok, household} =
      Households.update_features(
        scope.household,
        Map.merge(scope.household.features || %{}, %{"recipes" => true})
      )

    {:ok, Map.put(ctx, :scope, %{scope | household: household})}
  end

  defp enable_grocery(%{scope: scope} = ctx) do
    {:ok, household} =
      Households.update_features(
        scope.household,
        Map.merge(scope.household.features || %{}, %{"grocery" => true})
      )

    {:ok, Map.put(ctx, :scope, %{scope | household: household})}
  end
end
