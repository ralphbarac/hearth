defmodule HearthWeb.MealPlanLiveTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.CalendarFixtures
  import HearthWeb.RecipesFixtures
  import HearthWeb.GroceryFixtures

  alias Hearth.{Households, Links}
  alias HearthRecipes.Recipes
  alias HearthGrocery.{GroceryLists, GroceryItems}
  alias HearthCalendar.Events

  # --- Feature gate tests ---

  describe "feature gate" do
    setup :register_and_log_in_user

    test "redirects when no features enabled", %{conn: conn} do
      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/meal-plan")
    end

    test "redirects when only calendar enabled (recipes disabled)", %{conn: conn, scope: scope} do
      # Override to only calendar, no recipes
      {:ok, _} = Households.update_features(scope.household, %{"calendar" => true})
      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/meal-plan")
    end

    test "redirects when only recipes enabled (calendar disabled)", %{conn: conn, scope: scope} do
      # Override to only recipes, no calendar
      {:ok, _} = Households.update_features(scope.household, %{"recipes" => true})
      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/meal-plan")
    end
  end

  # --- Step 1: Plan details ---

  describe "step 1: plan name and date" do
    setup [:register_and_log_in_user, :enable_meal_plan_features]

    test "renders step 1 form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/meal-plan")
      assert html =~ "Meal Planner"
      assert html =~ "New Meal Plan"
      assert html =~ "Plan name"
    end

    test "advances to step 2 with recipes", %{conn: conn, scope: scope} do
      recipe_fixture(scope, %{"name" => "Pasta"})

      {:ok, view, _html} = live(conn, ~p"/meal-plan")
      submit_step_1(view)

      assert render(view) =~ "Select Recipes"
      assert render(view) =~ "Pasta"
    end

    test "shows empty state when no recipes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/meal-plan")
      submit_step_1(view)

      assert render(view) =~ "No recipes yet"
    end

    test "rejects blank plan name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/meal-plan")

      view
      |> form("form", %{"plan_name" => "", "plan_date" => "2026-03-10"})
      |> render_submit()

      assert render(view) =~ "New Meal Plan"
    end
  end

  # --- Step 2: Recipe selection ---

  describe "step 2: recipe selection" do
    setup [:register_and_log_in_user, :enable_meal_plan_features, :setup_with_recipes]

    test "shows all recipes selected by default", %{view: view, recipe1: r1, recipe2: r2} do
      html = render(view)
      assert html =~ r1.name
      assert html =~ r2.name
    end

    test "Next button disabled when all recipes deselected", %{
      view: view,
      recipe1: r1,
      recipe2: r2
    } do
      view |> element("[phx-click='toggle_recipe'][phx-value-id='#{r1.id}']") |> render_click()
      view |> element("[phx-click='toggle_recipe'][phx-value-id='#{r2.id}']") |> render_click()
      assert render(view) =~ ~s(disabled)
    end

    test "back returns to step 1", %{view: view} do
      view |> element("button", "← Back") |> render_click()
      assert render(view) =~ "New Meal Plan"
    end

    test "next advances to step 3 with ingredients", %{view: view} do
      view |> element("button", "Next →") |> render_click()
      assert render(view) =~ "Review Ingredients"
    end
  end

  # --- Full wizard flow ---

  describe "full wizard: creates events and grocery items" do
    setup [:register_and_log_in_user, :enable_meal_plan_features]

    test "completes full wizard with new grocery list", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope, %{"name" => "Carbonara"})

      {:ok, _} =
        Recipes.add_ingredient(scope, recipe, %{
          "name" => "Eggs",
          "quantity" => "4",
          "unit" => "pcs"
        })

      {:ok, _} =
        Recipes.add_ingredient(scope, recipe, %{
          "name" => "Bacon",
          "quantity" => "200",
          "unit" => "g"
        })

      {:ok, view, _html} = live(conn, ~p"/meal-plan")

      # Step 1
      submit_step_1(view, %{"plan_name" => "March Dinners", "plan_date" => "2026-03-15"})
      assert render(view) =~ "Carbonara"

      # Step 2 → Step 3
      view |> element("button", "Next →") |> render_click()
      assert render(view) =~ "Review Ingredients"
      assert render(view) =~ "Eggs"
      assert render(view) =~ "Bacon"

      # Step 3 → Step 4
      view |> element("button", "Next →") |> render_click()
      assert render(view) =~ "Choose Grocery List"
      # new_list_name pre-filled with plan name
      assert render(view) =~ "March Dinners"

      # Generate
      {:error, {:live_redirect, %{to: "/grocery"}}} =
        view
        |> form("form", %{"target_list_id" => "", "new_list_name" => "March Dinners"})
        |> render_submit()

      # Grocery list created with items
      lists = GroceryLists.list_grocery_lists(scope)
      list = Enum.find(lists, &(&1.name == "March Dinners"))
      assert list

      items = GroceryItems.list_items(scope, list)
      item_names = Enum.map(items, & &1.name)
      assert "Eggs" in item_names
      assert "Bacon" in item_names

      # Calendar event created for the recipe
      today = Date.utc_today()
      events = Events.list_events_for_range(scope, %{today | day: 1}, Date.end_of_month(today))
      assert Enum.any?(events, &(&1.title == "Carbonara"))

      carbonara_event = Enum.find(events, &(&1.title == "Carbonara"))
      # Event linked to recipe
      recipe_ids = Links.get_linked_ids(scope, "calendar_event", carbonara_event.id, "recipe")
      assert recipe.id in recipe_ids
      # Event linked to grocery list
      list_ids = Links.get_linked_ids(scope, "calendar_event", carbonara_event.id, "grocery_list")
      assert list.id in list_ids
    end

    test "adds to existing grocery list", %{conn: conn, scope: scope} do
      existing_list = grocery_list_fixture(scope, %{"name" => "Weekly Shop"})
      recipe = recipe_fixture(scope)

      {:ok, _} =
        Recipes.add_ingredient(scope, recipe, %{
          "name" => "Milk",
          "quantity" => "1",
          "unit" => "L"
        })

      {:ok, view, _html} = live(conn, ~p"/meal-plan")
      submit_step_1(view)
      view |> element("button", "Next →") |> render_click()
      view |> element("button", "Next →") |> render_click()

      {:error, {:live_redirect, %{to: "/grocery"}}} =
        view
        |> form("form", %{"target_list_id" => existing_list.id, "new_list_name" => ""})
        |> render_submit()

      items = GroceryItems.list_items(scope, existing_list)
      assert Enum.any?(items, &(&1.name == "Milk"))
    end

    test "creates one calendar event per selected recipe", %{conn: conn, scope: scope} do
      recipe1 = recipe_fixture(scope, %{"name" => "Pasta"})
      recipe2 = recipe_fixture(scope, %{"name" => "Salad"})

      {:ok, _} =
        Recipes.add_ingredient(scope, recipe1, %{
          "name" => "Flour",
          "quantity" => "200",
          "unit" => "g"
        })

      {:ok, view, _html} = live(conn, ~p"/meal-plan")
      submit_step_1(view, %{"plan_name" => "Test", "plan_date" => "2026-03-20"})
      view |> element("button", "Next →") |> render_click()
      view |> element("button", "Next →") |> render_click()

      {:error, {:live_redirect, %{to: "/grocery"}}} =
        view
        |> form("form", %{"target_list_id" => "", "new_list_name" => "Test List"})
        |> render_submit()

      today = Date.utc_today()
      events = Events.list_events_for_range(scope, %{today | day: 1}, Date.end_of_month(today))
      event_titles = Enum.map(events, & &1.title)
      assert "Pasta" in event_titles
      assert "Salad" in event_titles
      _ = recipe2
    end

    test "deselecting a recipe excludes its ingredients from step 3", %{conn: conn, scope: scope} do
      recipe1 = recipe_fixture(scope, %{"name" => "Soup"})
      recipe2 = recipe_fixture(scope, %{"name" => "Cake"})

      {:ok, _} =
        Recipes.add_ingredient(scope, recipe1, %{
          "name" => "Broth",
          "quantity" => "1",
          "unit" => "L"
        })

      {:ok, _} =
        Recipes.add_ingredient(scope, recipe2, %{
          "name" => "Flour",
          "quantity" => "200",
          "unit" => "g"
        })

      {:ok, view, _html} = live(conn, ~p"/meal-plan")
      submit_step_1(view)

      # Deselect Cake
      view
      |> element("[phx-click='toggle_recipe'][phx-value-id='#{recipe2.id}']")
      |> render_click()

      view |> element("button", "Next →") |> render_click()

      html = render(view)
      assert html =~ "Broth"
      refute html =~ "Flour"
    end

    test "excluding ingredient omits it from grocery list", %{conn: conn, scope: scope} do
      recipe = recipe_fixture(scope)

      {:ok, _} =
        Recipes.add_ingredient(scope, recipe, %{
          "name" => "Butter",
          "quantity" => "100",
          "unit" => "g"
        })

      {:ok, _} =
        Recipes.add_ingredient(scope, recipe, %{
          "name" => "Sugar",
          "quantity" => "50",
          "unit" => "g"
        })

      {:ok, view, _html} = live(conn, ~p"/meal-plan")
      submit_step_1(view)
      view |> element("button", "Next →") |> render_click()

      # Exclude Butter (alphabetically first → index 0)
      view
      |> element("[phx-click='toggle_ingredient'][phx-value-index='0']")
      |> render_click()

      view |> element("button", "Next →") |> render_click()

      {:error, {:live_redirect, %{to: "/grocery"}}} =
        view
        |> form("form", %{"target_list_id" => "", "new_list_name" => "Test"})
        |> render_submit()

      lists = GroceryLists.list_grocery_lists(scope)
      list = Enum.find(lists, &(&1.name == "Test"))
      items = GroceryItems.list_items(scope, list)
      item_names = Enum.map(items, & &1.name)

      assert "Sugar" in item_names
      refute "Butter" in item_names
    end
  end

  # --- Calendar recipe linking (still available for manual edits) ---

  describe "calendar recipe linking" do
    setup [:register_and_log_in_user, :enable_meal_plan_features]

    test "linked recipes section is visible when editing an event", %{conn: conn, scope: scope} do
      event = event_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/calendar")
      open_event_panel(view, event)
      assert render(view) =~ "Linked Recipes"
    end

    test "can link a recipe to an event from the calendar", %{conn: conn, scope: scope} do
      event = event_fixture(scope)
      recipe = recipe_fixture(scope, %{"name" => "My Lasagna"})

      {:ok, view, _html} = live(conn, ~p"/calendar")
      open_event_panel(view, event)

      view
      |> form("form[phx-submit='link_recipe']", %{"recipe_id" => recipe.id})
      |> render_submit()

      assert recipe.id in Links.get_linked_ids(scope, "calendar_event", event.id, "recipe")
    end

    test "can unlink a recipe from an event", %{conn: conn, scope: scope} do
      event = event_fixture(scope)
      recipe = recipe_fixture(scope, %{"name" => "Linked Recipe"})
      Links.create_link(scope, "calendar_event", event.id, "recipe", recipe.id)

      {:ok, view, _html} = live(conn, ~p"/calendar")
      open_event_panel(view, event)

      view
      |> element("[phx-click='unlink_recipe'][phx-value-recipe_id='#{recipe.id}']")
      |> render_click()

      refute recipe.id in Links.get_linked_ids(scope, "calendar_event", event.id, "recipe")
    end
  end

  # --- Helpers ---

  defp submit_step_1(view, params \\ %{}) do
    today = Date.utc_today()

    view
    |> form(
      "form",
      Map.merge(
        %{"plan_name" => "Test Plan", "plan_date" => Date.to_iso8601(%{today | day: 15})},
        params
      )
    )
    |> render_submit()
  end

  defp open_event_panel(view, event) do
    date = DateTime.to_date(event.starts_at)

    view
    |> element("[phx-click='select_date'][phx-value-date='#{Date.to_iso8601(date)}']")
    |> render_click()

    view |> element("[phx-click='edit_event'][phx-value-id='#{event.id}']") |> render_click()
  end

  defp enable_meal_plan_features(%{scope: scope} = ctx) do
    features =
      Map.merge(scope.household.features || %{}, %{"calendar" => true, "recipes" => true})

    {:ok, household} = Households.update_features(scope.household, features)
    {:ok, Map.put(ctx, :scope, %{scope | household: household})}
  end

  defp setup_with_recipes(%{conn: conn, scope: scope} = ctx) do
    recipe1 = recipe_fixture(scope, %{"name" => "Soup"})

    {:ok, _} =
      Recipes.add_ingredient(scope, recipe1, %{
        "name" => "Carrot",
        "quantity" => "2",
        "unit" => "pcs"
      })

    recipe2 = recipe_fixture(scope, %{"name" => "Salad"})

    {:ok, _} =
      Recipes.add_ingredient(scope, recipe2, %{
        "name" => "Lettuce",
        "quantity" => "1",
        "unit" => "head"
      })

    {:ok, view, _html} = live(conn, ~p"/meal-plan")
    submit_step_1(view)

    {:ok, Map.merge(ctx, %{view: view, recipe1: recipe1, recipe2: recipe2})}
  end
end
