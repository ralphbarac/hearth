defmodule HearthBudget.SavingGoalsFixtures do
  import Hearth.AccountsFixtures

  alias HearthBudget.SavingGoals

  def valid_saving_goal_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Goal #{System.unique_integer([:positive])}",
      "target_amount" => 100_000
    })
  end

  def saving_goal_fixture(scope \\ nil, attrs \\ %{}) do
    scope = scope || user_scope_fixture()
    {:ok, goal} = SavingGoals.create_goal(scope, valid_saving_goal_attributes(attrs))
    goal
  end
end
