defmodule HearthWeb.GoalsLiveTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.GoalsFixtures

  alias Hearth.Households
  alias HearthBudget.{SavingGoals, Categories, Transactions}

  describe "feature gate" do
    setup :register_and_log_in_user

    test "redirects when budget feature disabled", %{conn: conn, scope: scope} do
      {:ok, _} = Households.update_features(scope.household, %{"budget" => false})
      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/budget/goals")
    end
  end

  describe "goals list" do
    setup :register_and_log_in_user

    test "renders empty state when no goals", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budget/goals")
      assert html =~ "Savings Goals"
      assert html =~ "No savings goals yet"
    end

    test "renders active goals", %{conn: conn, scope: scope} do
      saving_goal_fixture(scope, %{"name" => "Japan Trip"})

      {:ok, _view, html} = live(conn, ~p"/budget/goals")
      assert html =~ "Japan Trip"
    end

    test "shows tab bar with Goals tab active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budget/goals")
      assert html =~ "tab-active"
      assert html =~ "Goals"
      assert html =~ "Transactions"
    end
  end

  describe "add goal" do
    setup :register_and_log_in_user

    test "opens form and creates goal", %{conn: conn, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/budget/goals")

      view |> element("button", "Add Goal") |> render_click()
      assert render(view) =~ "New Goal"

      view
      |> form("form", %{
        "saving_goal" => %{
          "name" => "Emergency Fund",
          "target_amount_input" => "500.00"
        }
      })
      |> render_submit()

      assert render(view) =~ "Emergency Fund"
      [goal] = SavingGoals.list_goals(scope)
      assert goal.name == "Emergency Fund"
      assert goal.target_amount == 50_000
    end

    test "shows validation error for missing name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget/goals")

      view |> element("button", "Add Goal") |> render_click()

      view
      |> form("form", %{
        "saving_goal" => %{
          "name" => "",
          "target_amount_input" => "100.00"
        }
      })
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end
  end

  describe "contribute to goal" do
    setup :register_and_log_in_user

    test "opens contribution form and creates transaction", %{conn: conn, scope: scope} do
      Categories.ensure_defaults(scope)
      goal = saving_goal_fixture(scope, %{"name" => "Vacation"})

      {:ok, view, _html} = live(conn, ~p"/budget/goals")

      view
      |> element("[phx-click='contribute'][phx-value-id='#{goal.id}']")
      |> render_click()

      assert render(view) =~ "Contribute to Vacation"

      view
      |> form("form", %{
        "transaction" => %{
          "amount_input" => "50.00",
          "date" => "2026-03-15"
        }
      })
      |> render_submit()

      [updated_goal] = SavingGoals.list_goals(scope)
      assert updated_goal.current_amount == 5000
    end

    test "contribution appears in transactions list", %{conn: conn, scope: scope} do
      Categories.ensure_defaults(scope)
      goal = saving_goal_fixture(scope, %{"name" => "Car Fund"})

      {:ok, view, _html} = live(conn, ~p"/budget/goals")

      view
      |> element("[phx-click='contribute'][phx-value-id='#{goal.id}']")
      |> render_click()

      view
      |> form("form", %{
        "transaction" => %{
          "amount_input" => "100.00",
          "date" => "2026-03-15"
        }
      })
      |> render_submit()

      transactions = Transactions.list_transactions(scope)
      assert length(transactions) == 1
      assert hd(transactions).saving_goal_id == goal.id
    end
  end

  describe "mark complete" do
    setup :register_and_log_in_user

    test "moves goal to completed section", %{conn: conn, scope: scope} do
      goal = saving_goal_fixture(scope, %{"name" => "Rainy Day Fund"})

      {:ok, view, _html} = live(conn, ~p"/budget/goals")

      view
      |> element("[phx-click='mark_complete'][phx-value-id='#{goal.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Completed"
      assert html =~ "Rainy Day Fund"
    end
  end

  describe "delete goal" do
    setup :register_and_log_in_user

    test "removes goal from list", %{conn: conn, scope: scope} do
      goal = saving_goal_fixture(scope, %{"name" => "To Delete"})

      {:ok, view, _html} = live(conn, ~p"/budget/goals")
      assert render(view) =~ "To Delete"

      view
      |> element("[phx-click='delete_goal'][phx-value-id='#{goal.id}']")
      |> render_click()

      refute render(view) =~ "To Delete"
      assert SavingGoals.list_goals(scope) == []
    end
  end

end
