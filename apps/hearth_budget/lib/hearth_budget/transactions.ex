defmodule HearthBudget.Transactions do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthBudget.Transaction

  @pubsub Hearth.PubSub
  @topic_prefix "household"
  @topic_suffix "budget"

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_transactions(%Scope{household: household}) do
    Transaction
    |> where([t], t.household_id == ^household.id)
    |> order_by([t], desc: t.date)
    |> preload(:category)
    |> Repo.all()
  end

  def list_transactions_for_month(%Scope{household: household}, {year, month}) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    Transaction
    |> where([t], t.household_id == ^household.id)
    |> where([t], t.date >= ^start_date and t.date <= ^end_date)
    |> order_by([t], desc: t.date)
    |> preload(:category)
    |> Repo.all()
  end

  def get_transaction!(%Scope{household: household}, id) do
    Transaction
    |> where([t], t.household_id == ^household.id and t.id == ^id)
    |> Repo.one!()
  end

  def change_transaction(%Transaction{} = transaction, attrs \\ %{}) do
    Transaction.changeset(transaction, attrs)
  end

  def create_transaction(%Scope{household: household, user: user}, attrs) do
    %Transaction{}
    |> Transaction.changeset(
      Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id})
    )
    |> Repo.insert()
    |> tap_broadcast(:created, household.id)
  end

  def update_transaction(%Scope{}, %Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, transaction.household_id)
  end

  def delete_transaction(%Scope{}, %Transaction{} = transaction) do
    Repo.delete(transaction)
    |> tap_broadcast(:deleted, transaction.household_id)
  end

  def spending_by_category(%Scope{} = scope, {year, month}) do
    transactions = list_transactions_for_month(scope, {year, month})

    transactions
    |> Enum.filter(&(&1.type == "expense"))
    |> Enum.group_by(fn t ->
      if t.category, do: t.category.name, else: "Other"
    end)
    |> Enum.map(fn {name, txns} ->
      total = txns |> Enum.map(& &1.amount) |> Enum.sum()
      %{name: name, total: total}
    end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  def monthly_summaries(%Scope{} = scope, n \\ 6) do
    today = Date.utc_today()
    current = Date.new!(today.year, today.month, 1)

    Enum.map(0..(n - 1), fn i ->
      date = Date.shift(current, month: -(n - 1 - i))
      transactions = list_transactions_for_month(scope, {date.year, date.month})

      income =
        transactions |> Enum.filter(&(&1.type == "income")) |> Enum.map(& &1.amount) |> Enum.sum()

      expenses =
        transactions
        |> Enum.filter(&(&1.type == "expense"))
        |> Enum.map(& &1.amount)
        |> Enum.sum()

      %{label: Calendar.strftime(date, "%b %y"), income: income, expenses: expenses}
    end)
  end

  def monthly_summary(%Scope{} = scope, {year, month}) do
    transactions = list_transactions_for_month(scope, {year, month})

    income =
      transactions |> Enum.filter(&(&1.type == "income")) |> Enum.map(& &1.amount) |> Enum.sum()

    expenses =
      transactions |> Enum.filter(&(&1.type == "expense")) |> Enum.map(& &1.amount) |> Enum.sum()

    %{income: income, expenses: expenses, net: income - expenses}
  end

  defp topic(household_id), do: "#{@topic_prefix}:#{household_id}:#{@topic_suffix}"

  defp tap_broadcast({:ok, transaction} = result, action, household_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, transaction})
    result
  end

  defp tap_broadcast(error, _action, _household_id), do: error
end
