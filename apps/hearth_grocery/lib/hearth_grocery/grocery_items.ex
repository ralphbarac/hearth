defmodule HearthGrocery.GroceryItems do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthGrocery.GroceryItem
  alias HearthGrocery.GroceryList

  @pubsub Hearth.PubSub
  @topic_prefix "household"
  @topic_suffix "grocery"

  def list_items(%Scope{household: household}, %GroceryList{} = list) do
    GroceryItem
    |> join(:inner, [i], l in GroceryList, on: i.list_id == l.id)
    |> where([i, l], l.household_id == ^household.id and i.list_id == ^list.id)
    |> order_by([i], asc: i.position, asc: i.inserted_at)
    |> Repo.all()
  end

  def get_item!(%Scope{household: household}, id) do
    GroceryItem
    |> join(:inner, [i], l in GroceryList, on: i.list_id == l.id)
    |> where([i, l], l.household_id == ^household.id and i.id == ^id)
    |> Repo.one!()
  end

  def change_item(%GroceryItem{} = item, attrs \\ %{}) do
    GroceryItem.changeset(item, attrs)
  end

  def create_item(%Scope{user: user, household: household}, %GroceryList{} = list, attrs) do
    position = next_position(list.id)

    %GroceryItem{}
    |> GroceryItem.changeset(
      Map.merge(attrs, %{
        "list_id" => list.id,
        "added_by_id" => user.id,
        "position" => position
      })
    )
    |> Repo.insert()
    |> tap_broadcast(:created, household.id)
  end

  def update_item(%Scope{household: household}, %GroceryItem{} = item, attrs) do
    item
    |> GroceryItem.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, household.id)
  end

  def delete_item(%Scope{household: household}, %GroceryItem{} = item) do
    Repo.delete(item)
    |> tap_broadcast(:deleted, household.id)
  end

  def toggle_checked(%Scope{} = scope, %GroceryItem{} = item) do
    update_item(scope, item, %{"checked" => !item.checked})
  end

  defp next_position(list_id) do
    max_pos =
      GroceryItem
      |> where([i], i.list_id == ^list_id)
      |> select([i], max(i.position))
      |> Repo.one()

    (max_pos || 0) + 1
  end

  defp topic(household_id), do: "#{@topic_prefix}:#{household_id}:#{@topic_suffix}"

  defp tap_broadcast({:ok, item} = result, action, household_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, item})
    result
  end

  defp tap_broadcast(error, _action, _household_id), do: error
end
