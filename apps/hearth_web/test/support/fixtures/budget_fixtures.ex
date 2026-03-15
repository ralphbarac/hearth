defmodule HearthWeb.BudgetFixtures do
  alias HearthBudget.Transactions

  def valid_transaction_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "description" => "Test Transaction #{System.unique_integer([:positive])}",
      "amount" => 1000,
      "type" => "expense",
      "date" => "2026-03-05"
    })
  end

  def transaction_fixture(scope, attrs \\ %{}) do
    {:ok, transaction} =
      Transactions.create_transaction(scope, valid_transaction_attributes(attrs))

    transaction
  end
end
