defmodule HearthBudget.BudgetFixtures do
  alias HearthBudget.Transactions
  alias HearthBudget.Category
  alias Hearth.Repo

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

  def category_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Test Category #{System.unique_integer([:positive])}",
        type: "expense",
        household_id: scope.household.id
      })

    {:ok, category} =
      %Category{}
      |> Category.changeset(attrs)
      |> Repo.insert()

    category
  end
end
