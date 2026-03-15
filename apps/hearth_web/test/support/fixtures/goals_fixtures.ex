defmodule HearthWeb.GoalsFixtures do
  alias HearthBudget.SavingGoals

  def valid_saving_goal_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Goal #{System.unique_integer([:positive])}",
      "target_amount" => 100_000
    })
  end

  def saving_goal_fixture(scope, attrs \\ %{}) do
    {:ok, goal} = SavingGoals.create_goal(scope, valid_saving_goal_attributes(attrs))
    goal
  end
end
