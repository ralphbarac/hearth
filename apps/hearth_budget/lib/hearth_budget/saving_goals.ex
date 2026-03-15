defmodule HearthBudget.SavingGoals do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthBudget.SavingGoal
  alias HearthBudget.Transaction
  alias HearthBudget.Categories

  @pubsub Hearth.PubSub
  @topic_prefix "household"
  @topic_suffix "budget"

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_goals(%Scope{household: household}) do
    from(g in SavingGoal,
      where: g.household_id == ^household.id,
      left_join: t in Transaction,
      on: t.saving_goal_id == g.id,
      group_by: g.id,
      select: %{g | current_amount: coalesce(sum(t.amount), 0)},
      order_by: [asc: g.is_complete, asc: g.inserted_at]
    )
    |> Repo.all()
  end

  def get_goal!(%Scope{household: household}, id) do
    SavingGoal
    |> where([g], g.household_id == ^household.id and g.id == ^id)
    |> Repo.one!()
  end

  def change_goal(%Scope{}, %SavingGoal{} = goal, attrs \\ %{}) do
    SavingGoal.changeset(goal, attrs)
  end

  def create_goal(%Scope{household: household, user: user}, attrs) do
    %SavingGoal{}
    |> SavingGoal.changeset(
      Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id})
    )
    |> Repo.insert()
    |> tap_broadcast(:created, household.id)
  end

  def update_goal(%Scope{household: household}, %SavingGoal{} = goal, attrs) do
    goal
    |> SavingGoal.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, household.id)
  end

  def delete_goal(%Scope{household: household}, %SavingGoal{} = goal)
      when goal.household_id == household.id do
    Repo.delete(goal)
    |> tap_broadcast(:deleted, household.id)
  end

  def add_contribution(%Scope{household: household, user: user} = scope, %SavingGoal{} = goal, attrs) do
    savings_category_id = find_savings_category_id(scope)

    base_attrs = %{
      "type" => "expense",
      "saving_goal_id" => goal.id,
      "household_id" => household.id,
      "created_by_id" => user.id
    }

    default_description = %{"description" => "Contribution to #{goal.name}"}
    default_category = if savings_category_id, do: %{"category_id" => savings_category_id}, else: %{}

    merged =
      default_description
      |> Map.merge(default_category)
      |> Map.merge(attrs)
      |> Map.merge(base_attrs)

    result =
      %Transaction{}
      |> Transaction.changeset(merged)
      |> Repo.insert()

    case result do
      {:ok, transaction} ->
        Phoenix.PubSub.broadcast(@pubsub, topic(household.id), {__MODULE__, :contribution_added, goal})
        {:ok, transaction}

      error ->
        error
    end
  end

  def mark_complete(%Scope{} = scope, %SavingGoal{} = goal) do
    update_goal(scope, goal, %{"is_complete" => true})
  end

  defp find_savings_category_id(scope) do
    scope
    |> Categories.list_categories()
    |> Enum.find(&(&1.name == "Savings"))
    |> case do
      nil -> nil
      cat -> cat.id
    end
  end

  defp topic(household_id), do: "#{@topic_prefix}:#{household_id}:#{@topic_suffix}"

  defp tap_broadcast({:ok, goal} = result, action, household_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, goal})
    result
  end

  defp tap_broadcast(error, _action, _household_id), do: error
end
