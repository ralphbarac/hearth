defmodule HearthBudget.SavingGoalsTest do
  use HearthBudget.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthBudget.SavingGoalsFixtures

  alias HearthBudget.SavingGoals
  alias HearthBudget.SavingGoal
  alias HearthBudget.Categories

  describe "list_goals/1" do
    test "returns empty list with no goals" do
      scope = user_scope_fixture()
      assert SavingGoals.list_goals(scope) == []
    end

    test "returns only own household's goals" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      g1 = saving_goal_fixture(scope1)
      _g2 = saving_goal_fixture(scope2)

      results = SavingGoals.list_goals(scope1)
      assert length(results) == 1
      assert hd(results).id == g1.id
    end

    test "returns current_amount as 0 for new goal" do
      scope = user_scope_fixture()
      _goal = saving_goal_fixture(scope)

      [result] = SavingGoals.list_goals(scope)
      assert result.current_amount == 0
    end

    test "returns current_amount as sum of linked transactions" do
      scope = user_scope_fixture()
      Categories.ensure_defaults(scope)
      goal = saving_goal_fixture(scope)

      {:ok, _} =
        SavingGoals.add_contribution(scope, goal, %{
          "amount" => 5000,
          "date" => "2026-03-01"
        })

      {:ok, _} =
        SavingGoals.add_contribution(scope, goal, %{
          "amount" => 3000,
          "date" => "2026-03-05"
        })

      [result] = SavingGoals.list_goals(scope)
      assert result.current_amount == 8000
    end

    test "orders active goals before completed" do
      scope = user_scope_fixture()
      active = saving_goal_fixture(scope, %{"name" => "Active Goal"})
      completed = saving_goal_fixture(scope, %{"name" => "Completed Goal"})
      {:ok, _} = SavingGoals.mark_complete(scope, completed)

      results = SavingGoals.list_goals(scope)
      ids = Enum.map(results, & &1.id)
      assert Enum.find_index(ids, &(&1 == active.id)) <
               Enum.find_index(ids, &(&1 == completed.id))
    end
  end

  describe "create_goal/2" do
    test "creates goal with valid attrs" do
      scope = user_scope_fixture()
      attrs = valid_saving_goal_attributes(%{"name" => "Trip to Japan"})

      assert {:ok, %SavingGoal{} = goal} = SavingGoals.create_goal(scope, attrs)
      assert goal.name == "Trip to Japan"
      assert goal.household_id == scope.household.id
      assert goal.created_by_id == scope.user.id
      assert goal.is_complete == false
    end

    test "converts target_amount_input string to cents" do
      scope = user_scope_fixture()
      attrs = valid_saving_goal_attributes(%{"target_amount_input" => "250.00"})

      assert {:ok, goal} = SavingGoals.create_goal(scope, attrs)
      assert goal.target_amount == 25_000
    end

    test "returns error with missing required fields" do
      scope = user_scope_fixture()
      assert {:error, changeset} = SavingGoals.create_goal(scope, %{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:target_amount]
    end

    test "returns error when target_amount is zero" do
      scope = user_scope_fixture()
      attrs = valid_saving_goal_attributes(%{"target_amount" => 0})
      assert {:error, changeset} = SavingGoals.create_goal(scope, attrs)
      assert errors_on(changeset)[:target_amount]
    end

    test "accepts optional target_date and notes" do
      scope = user_scope_fixture()

      attrs =
        valid_saving_goal_attributes(%{
          "target_date" => "2027-06-01",
          "notes" => "Summer trip"
        })

      assert {:ok, goal} = SavingGoals.create_goal(scope, attrs)
      assert goal.target_date == ~D[2027-06-01]
      assert goal.notes == "Summer trip"
    end
  end

  describe "update_goal/3" do
    test "updates goal with valid attrs" do
      scope = user_scope_fixture()
      goal = saving_goal_fixture(scope)

      assert {:ok, updated} = SavingGoals.update_goal(scope, goal, %{"name" => "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "returns error with invalid attrs" do
      scope = user_scope_fixture()
      goal = saving_goal_fixture(scope)

      assert {:error, changeset} = SavingGoals.update_goal(scope, goal, %{"name" => ""})
      assert errors_on(changeset)[:name]
    end
  end

  describe "delete_goal/2" do
    test "removes goal" do
      scope = user_scope_fixture()
      goal = saving_goal_fixture(scope)

      assert {:ok, _} = SavingGoals.delete_goal(scope, goal)
      assert SavingGoals.list_goals(scope) == []
    end
  end

  describe "get_goal!/2" do
    test "returns own goal" do
      scope = user_scope_fixture()
      goal = saving_goal_fixture(scope)

      assert fetched = SavingGoals.get_goal!(scope, goal.id)
      assert fetched.id == goal.id
    end

    test "raises for another household's goal" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      goal = saving_goal_fixture(scope1)

      assert_raise Ecto.NoResultsError, fn ->
        SavingGoals.get_goal!(scope2, goal.id)
      end
    end
  end

  describe "add_contribution/3" do
    test "creates a transaction with saving_goal_id" do
      scope = user_scope_fixture()
      Categories.ensure_defaults(scope)
      goal = saving_goal_fixture(scope)

      assert {:ok, transaction} =
               SavingGoals.add_contribution(scope, goal, %{
                 "amount" => 5000,
                 "date" => "2026-03-01"
               })

      assert transaction.saving_goal_id == goal.id
      assert transaction.type == "expense"
      assert transaction.household_id == scope.household.id
    end

    test "defaults description to 'Contribution to <goal name>'" do
      scope = user_scope_fixture()
      Categories.ensure_defaults(scope)
      goal = saving_goal_fixture(scope, %{"name" => "Emergency Fund"})

      {:ok, transaction} =
        SavingGoals.add_contribution(scope, goal, %{
          "amount" => 1000,
          "date" => "2026-03-01"
        })

      assert transaction.description == "Contribution to Emergency Fund"
    end

    test "allows custom description" do
      scope = user_scope_fixture()
      Categories.ensure_defaults(scope)
      goal = saving_goal_fixture(scope)

      {:ok, transaction} =
        SavingGoals.add_contribution(scope, goal, %{
          "amount" => 1000,
          "date" => "2026-03-01",
          "description" => "Monthly savings"
        })

      assert transaction.description == "Monthly savings"
    end

    test "updates current_amount via list_goals after contribution" do
      scope = user_scope_fixture()
      Categories.ensure_defaults(scope)
      goal = saving_goal_fixture(scope)

      {:ok, _} =
        SavingGoals.add_contribution(scope, goal, %{"amount" => 7500, "date" => "2026-03-01"})

      [result] = SavingGoals.list_goals(scope)
      assert result.current_amount == 7500
    end

    test "returns error with missing amount" do
      scope = user_scope_fixture()
      Categories.ensure_defaults(scope)
      goal = saving_goal_fixture(scope)

      assert {:error, changeset} =
               SavingGoals.add_contribution(scope, goal, %{"date" => "2026-03-01"})

      assert errors_on(changeset)[:amount]
    end
  end

  describe "mark_complete/2" do
    test "sets is_complete to true" do
      scope = user_scope_fixture()
      goal = saving_goal_fixture(scope)

      assert {:ok, updated} = SavingGoals.mark_complete(scope, goal)
      assert updated.is_complete == true
    end
  end

  describe "household isolation" do
    test "cannot access another household's goals via list_goals" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      _g = saving_goal_fixture(scope1)

      assert SavingGoals.list_goals(scope2) == []
    end
  end
end
