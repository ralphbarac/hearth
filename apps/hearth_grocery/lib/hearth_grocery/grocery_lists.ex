defmodule HearthGrocery.GroceryLists do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthGrocery.GroceryList

  @pubsub Hearth.PubSub
  @topic_prefix "household"
  @topic_suffix "grocery"

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_grocery_lists(%Scope{household: household}) do
    GroceryList
    |> where([l], l.household_id == ^household.id)
    |> order_by([l], desc: l.inserted_at)
    |> Repo.all()
  end

  def get_grocery_list!(%Scope{household: household}, id) do
    GroceryList
    |> where([l], l.household_id == ^household.id and l.id == ^id)
    |> Repo.one!()
  end

  def change_grocery_list(%GroceryList{} = list, attrs \\ %{}) do
    GroceryList.changeset(list, attrs)
  end

  def create_grocery_list(%Scope{household: household, user: user}, attrs) do
    %GroceryList{}
    |> GroceryList.changeset(
      Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id})
    )
    |> Repo.insert()
    |> tap_broadcast(:created, household.id)
  end

  def update_grocery_list(%Scope{}, %GroceryList{} = list, attrs) do
    list
    |> GroceryList.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, list.household_id)
  end

  def delete_grocery_list(%Scope{}, %GroceryList{} = list) do
    Repo.delete(list)
    |> tap_broadcast(:deleted, list.household_id)
  end

  defp topic(household_id), do: "#{@topic_prefix}:#{household_id}:#{@topic_suffix}"

  defp tap_broadcast({:ok, list} = result, action, household_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, list})
    result
  end

  defp tap_broadcast(error, _action, _household_id), do: error
end
