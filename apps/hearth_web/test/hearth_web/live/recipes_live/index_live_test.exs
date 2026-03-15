defmodule HearthWeb.RecipesLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.RecipesFixtures

  alias Hearth.Households
  alias HearthRecipes.Recipes

  describe "feature disabled" do
    setup :register_and_log_in_user

    test "redirects to dashboard when feature disabled", %{conn: conn} do
      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/recipes")
    end
  end

  describe "Recipes page" do
    setup [:register_and_log_in_user, :enable_recipes]

    test "renders page header with Recipes and New Recipe button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/recipes")
      assert html =~ "Recipes"
      assert html =~ "New Recipe"
    end

    test "shows empty state when no recipes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/recipes")
      assert html =~ "No recipes yet"
    end

    test "lists existing recipes", %{conn: conn, scope: scope} do
      recipe_fixture(scope, %{"name" => "Grandma's Pie"})
      {:ok, _view, html} = live(conn, ~p"/recipes")
      assert html =~ "Grandma&#39;s Pie"
    end

    test "opens new recipe form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/recipes")
      view |> element("button", "New Recipe") |> render_click()
      assert render(view) =~ "New Recipe"
    end

    test "creates recipe successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/recipes")
      view |> element("button", "New Recipe") |> render_click()

      view
      |> form("form", recipe: %{name: "My New Recipe"})
      |> render_submit()

      assert render(view) =~ "My New Recipe"
    end

    test "deletes recipe", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope, %{"name" => "To Delete"})

      {:ok, view, _html} = live(conn, ~p"/recipes")
      assert render(view) =~ "To Delete"

      view
      |> element("[phx-click='delete_recipe'][phx-value-id='#{recipe.id}']")
      |> render_click()

      refute render(view) =~ "To Delete"
    end

    test "tag filter bar appears when tags exist", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope)
      tag = tag_fixture(scope, %{"name" => "Italian"})
      Recipes.set_tags(scope, recipe, [tag.id])

      {:ok, _view, html} = live(conn, ~p"/recipes")
      assert html =~ "Italian"
    end

    test "filter by tag narrows results", %{conn: conn, scope: scope} do
      recipe1 = recipe_fixture(scope, %{"name" => "Pasta"})
      recipe_fixture(scope, %{"name" => "Steak"})
      tag = tag_fixture(scope, %{"name" => "Italian"})
      Recipes.set_tags(scope, recipe1, [tag.id])

      {:ok, view, _html} = live(conn, ~p"/recipes")
      assert render(view) =~ "Pasta"
      assert render(view) =~ "Steak"

      view |> element("[phx-click='filter_tag'][phx-value-id='#{tag.id}']") |> render_click()

      assert render(view) =~ "Pasta"
      refute render(view) =~ "Steak"
    end

    test "clear filter shows all recipes again", %{conn: conn, scope: scope} do
      recipe1 = recipe_fixture(scope, %{"name" => "Pasta"})
      recipe_fixture(scope, %{"name" => "Steak"})
      tag = tag_fixture(scope, %{"name" => "Italian"})
      Recipes.set_tags(scope, recipe1, [tag.id])

      {:ok, view, _html} = live(conn, ~p"/recipes")

      view |> element("[phx-click='filter_tag'][phx-value-id='#{tag.id}']") |> render_click()
      refute render(view) =~ "Steak"

      view |> element("button", "Clear") |> render_click()
      assert render(view) =~ "Steak"
    end
  end

  defp enable_recipes(%{scope: scope} = ctx) do
    features = Map.get(scope.household.features || %{}, "recipes", false)

    unless features do
      {:ok, household} =
        Households.update_features(
          scope.household,
          Map.merge(scope.household.features || %{}, %{"recipes" => true})
        )

      updated_scope = %{scope | household: household}
      {:ok, Map.put(ctx, :scope, updated_scope)}
    else
      :ok
    end
  end
end
