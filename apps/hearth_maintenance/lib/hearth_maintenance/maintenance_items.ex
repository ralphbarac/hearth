defmodule HearthMaintenance.MaintenanceItems do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthMaintenance.{MaintenanceItem, MaintenanceRecord}

  @pubsub Hearth.PubSub

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_items(%Scope{household: household}) do
    MaintenanceItem
    |> where([i], i.household_id == ^household.id)
    |> order_by([i], asc: i.next_due_date)
    |> Repo.all()
  end

  def list_items_due_soon(%Scope{household: household}, days \\ 30) do
    cutoff = Date.add(Date.utc_today(), days)

    MaintenanceItem
    |> where([i], i.household_id == ^household.id and i.is_active == true)
    |> where([i], i.next_due_date <= ^cutoff)
    |> order_by([i], asc: i.next_due_date)
    |> Repo.all()
  end

  def get_item!(%Scope{household: household}, id) do
    MaintenanceItem
    |> where([i], i.household_id == ^household.id and i.id == ^id)
    |> Repo.one!()
  end

  def change_item(%Scope{}, %MaintenanceItem{} = item, attrs \\ %{}) do
    MaintenanceItem.changeset(item, attrs)
  end

  def create_item(%Scope{user: user, household: household}, attrs) do
    %MaintenanceItem{}
    |> MaintenanceItem.changeset(Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id}))
    |> Repo.insert()
    |> tap_broadcast(household.id, :created)
  end

  def update_item(%Scope{household: household}, %MaintenanceItem{} = item, attrs) do
    item
    |> MaintenanceItem.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(household.id, :updated)
  end

  def delete_item(%Scope{household: household}, %MaintenanceItem{} = item) do
    Repo.delete(item)
    |> tap_broadcast(household.id, :deleted)
  end

  def log_maintenance(%Scope{user: user, household: household}, %MaintenanceItem{} = item, attrs) do
    record_attrs = Map.merge(attrs, %{
      "item_id" => item.id,
      "household_id" => household.id,
      "performed_by_id" => user.id
    })

    changeset = MaintenanceRecord.changeset(%MaintenanceRecord{}, record_attrs)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:record, changeset)
      |> Ecto.Multi.run(:item, fn _repo, %{record: record} ->
        new_due_date = Date.add(record.performed_on, item.interval_days)

        item
        |> MaintenanceItem.changeset(%{"next_due_date" => new_due_date})
        |> Repo.update()
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{item: updated_item}} ->
        Phoenix.PubSub.broadcast(@pubsub, topic(household.id), {__MODULE__, :logged, updated_item})
        {:ok, updated_item}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def list_records(%Scope{household: household}, %MaintenanceItem{} = item) do
    MaintenanceRecord
    |> where([r], r.household_id == ^household.id and r.item_id == ^item.id)
    |> order_by([r], desc: r.performed_on)
    |> Repo.all()
  end

  defp topic(household_id), do: "household:#{household_id}:maintenance"

  defp tap_broadcast({:ok, item} = result, household_id, action) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, item})
    result
  end

  defp tap_broadcast(error, _household_id, _action), do: error
end
