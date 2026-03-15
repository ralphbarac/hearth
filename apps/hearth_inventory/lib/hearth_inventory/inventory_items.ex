defmodule HearthInventory.InventoryItems do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthInventory.InventoryItem

  @pubsub Hearth.PubSub
  @topic_prefix "household"
  @topic_suffix "inventory"

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_items(%Scope{household: household}) do
    InventoryItem
    |> where([i], i.household_id == ^household.id)
    |> order_by([i], asc: i.name)
    |> Repo.all()
  end

  def list_low_stock_items(%Scope{household: household}) do
    InventoryItem
    |> where([i], i.household_id == ^household.id)
    |> where([i], i.min_quantity > 0 and i.quantity < i.min_quantity)
    |> order_by([i], asc: i.name)
    |> Repo.all()
  end

  def get_item!(%Scope{household: household}, id) do
    InventoryItem
    |> where([i], i.household_id == ^household.id and i.id == ^id)
    |> Repo.one!()
  end

  def change_item(%InventoryItem{} = item, attrs \\ %{}) do
    InventoryItem.changeset(item, attrs)
  end

  def create_item(%Scope{user: user, household: household}, attrs) do
    %InventoryItem{}
    |> InventoryItem.changeset(
      Map.merge(attrs, %{
        "household_id" => household.id,
        "created_by_id" => user.id
      })
    )
    |> Repo.insert()
    |> tap_broadcast(:created, household.id)
  end

  def update_item(%Scope{household: household}, %InventoryItem{} = item, attrs) do
    item
    |> InventoryItem.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, household.id)
  end

  def delete_item(%Scope{household: household}, %InventoryItem{} = item) do
    Repo.delete(item)
    |> tap_broadcast(:deleted, household.id)
  end

  def adjust_quantity(%Scope{} = scope, %InventoryItem{} = item, delta) do
    new_quantity = max(0, item.quantity + delta)
    update_item(scope, item, %{"quantity" => new_quantity})
  end

  defp topic(household_id), do: "#{@topic_prefix}:#{household_id}:#{@topic_suffix}"

  defp tap_broadcast({:ok, item} = result, action, household_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, item})
    result
  end

  defp tap_broadcast(error, _action, _household_id), do: error
end
