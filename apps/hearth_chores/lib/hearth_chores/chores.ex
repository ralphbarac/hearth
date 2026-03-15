defmodule HearthChores.Chores do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthChores.{Chore, ChoreCompletion}

  @pubsub Hearth.PubSub

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_chores(%Scope{household: household}) do
    Chore
    |> where([c], c.household_id == ^household.id)
    |> order_by([c], asc: c.next_due_date)
    |> preload(:assigned_to)
    |> Repo.all()
  end

  def list_chores_due_soon(%Scope{household: household}, days \\ 7) do
    cutoff = Date.add(Date.utc_today(), days)

    Chore
    |> where([c], c.household_id == ^household.id and c.is_active == true)
    |> where([c], c.next_due_date <= ^cutoff)
    |> order_by([c], asc: c.next_due_date)
    |> preload(:assigned_to)
    |> Repo.all()
  end

  def list_chores_for_user(%Scope{household: household}, user_id) do
    Chore
    |> where([c], c.household_id == ^household.id and c.assigned_to_id == ^user_id)
    |> order_by([c], asc: c.next_due_date)
    |> preload(:assigned_to)
    |> Repo.all()
  end

  def get_chore!(%Scope{household: household}, id) do
    Chore
    |> where([c], c.household_id == ^household.id and c.id == ^id)
    |> preload(:assigned_to)
    |> Repo.one!()
  end

  def change_chore(%Scope{}, %Chore{} = chore, attrs \\ %{}) do
    Chore.changeset(chore, attrs)
  end

  def create_chore(%Scope{user: user, household: household}, attrs) do
    %Chore{}
    |> Chore.changeset(Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id}))
    |> Repo.insert()
    |> tap_broadcast(household.id, :created)
  end

  def update_chore(%Scope{household: household}, %Chore{} = chore, attrs) do
    chore
    |> Chore.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(household.id, :updated)
  end

  def delete_chore(%Scope{household: household}, %Chore{} = chore) do
    Repo.delete(chore)
    |> tap_broadcast(household.id, :deleted)
  end

  def complete_chore(%Scope{user: user, household: household}, %Chore{} = chore, notes \\ nil) do
    today = Date.utc_today()
    new_due_date = advance_due_date(chore.next_due_date, chore.frequency)
    is_active = chore.frequency != "once"

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:completion, %ChoreCompletion{
        chore_id: chore.id,
        household_id: household.id,
        completed_by_id: user.id,
        completed_on: today,
        notes: notes
      })
      |> Ecto.Multi.update(:chore, Chore.changeset(chore, %{
        "next_due_date" => new_due_date,
        "is_active" => is_active
      }))
      |> Repo.transaction()

    case result do
      {:ok, %{chore: updated_chore}} ->
        Phoenix.PubSub.broadcast(@pubsub, topic(household.id), {__MODULE__, :completed, updated_chore})
        {:ok, updated_chore}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def list_completions(%Scope{household: household}, %Chore{} = chore) do
    ChoreCompletion
    |> where([cc], cc.household_id == ^household.id and cc.chore_id == ^chore.id)
    |> order_by([cc], desc: cc.completed_on)
    |> Repo.all()
  end

  defp advance_due_date(date, "once"), do: date
  defp advance_due_date(date, "daily"), do: Date.add(date, 1)
  defp advance_due_date(date, "weekly"), do: Date.add(date, 7)
  defp advance_due_date(date, "biweekly"), do: Date.add(date, 14)
  defp advance_due_date(date, "monthly"), do: Date.shift(date, month: 1)

  defp topic(household_id), do: "household:#{household_id}:chores"

  defp tap_broadcast({:ok, chore} = result, household_id, action) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, chore})
    result
  end

  defp tap_broadcast(error, _household_id, _action), do: error
end
