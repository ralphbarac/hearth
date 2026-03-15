defmodule HearthBudget.Bills do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthBudget.Bill
  alias HearthBudget.Transactions

  @pubsub Hearth.PubSub
  @topic_prefix "household"
  @topic_suffix "budget"

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_bills(%Scope{household: household}) do
    Bill
    |> where([b], b.household_id == ^household.id)
    |> order_by([b], b.next_due_date)
    |> preload(:category)
    |> Repo.all()
  end

  def list_active_bills(%Scope{household: household}) do
    Bill
    |> where([b], b.household_id == ^household.id and b.is_active == true)
    |> order_by([b], b.next_due_date)
    |> preload(:category)
    |> Repo.all()
  end

  def list_bills_due_soon(%Scope{household: household}, days \\ 7) do
    today = Date.utc_today()
    cutoff = Date.add(today, days)

    Bill
    |> where([b], b.household_id == ^household.id)
    |> where([b], b.is_active == true)
    |> where([b], b.next_due_date <= ^cutoff)
    |> order_by([b], b.next_due_date)
    |> preload(:category)
    |> Repo.all()
  end

  def get_bill!(%Scope{household: household}, id) do
    Bill
    |> where([b], b.household_id == ^household.id and b.id == ^id)
    |> Repo.one!()
  end

  def change_bill(%Bill{} = bill, attrs \\ %{}) do
    Bill.changeset(bill, attrs)
  end

  def create_bill(%Scope{household: household, user: user}, attrs) do
    %Bill{}
    |> Bill.changeset(
      Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id})
    )
    |> Repo.insert()
    |> tap_broadcast(:created, household.id)
  end

  def update_bill(%Scope{}, %Bill{} = bill, attrs) do
    bill
    |> Bill.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, bill.household_id)
  end

  def delete_bill(%Scope{}, %Bill{} = bill) do
    Repo.delete(bill)
    |> tap_broadcast(:deleted, bill.household_id)
  end

  def mark_paid(%Scope{} = scope, %Bill{} = bill) do
    new_due_date = advance_due_date(bill.next_due_date, bill.frequency)

    result =
      bill
      |> Bill.changeset(%{"next_due_date" => new_due_date})
      |> Repo.update()

    case result do
      {:ok, updated_bill} ->
        if bill.auto_create_transaction do
          Transactions.create_transaction(scope, %{
            "description" => "#{bill.name} (auto)",
            "amount" => bill.amount,
            "type" => bill.type,
            "date" => Date.to_string(Date.utc_today()),
            "category_id" => bill.category_id
          })
        end

        tap_broadcast({:ok, updated_bill}, :paid, bill.household_id)

      error ->
        error
    end
  end

  def process_overdue_for_all_households do
    today = Date.utc_today()

    bills =
      Bill
      |> where([b], b.next_due_date <= ^today)
      |> where([b], b.is_active == true)
      |> where([b], b.auto_create_transaction == true)
      |> preload([:household, :created_by])
      |> Repo.all()

    bills
    |> Enum.filter(fn bill -> Hearth.Households.feature_enabled?(bill.household, "budget") end)
    |> Enum.each(fn bill ->
      user = bill.created_by

      if user do
        scope = %Hearth.Accounts.Scope{user: user, household: bill.household}
        mark_paid(scope, bill)
      end
    end)
  end

  defp advance_due_date(date, "weekly"), do: Date.add(date, 7)
  defp advance_due_date(date, "bi_weekly"), do: Date.add(date, 14)
  defp advance_due_date(date, "monthly"), do: Date.shift(date, month: 1)
  defp advance_due_date(date, "quarterly"), do: Date.shift(date, month: 3)
  defp advance_due_date(date, "yearly"), do: Date.shift(date, year: 1)

  defp topic(household_id), do: "#{@topic_prefix}:#{household_id}:#{@topic_suffix}"

  defp tap_broadcast({:ok, bill} = result, action, household_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, bill})
    result
  end

  defp tap_broadcast(error, _action, _household_id), do: error
end
