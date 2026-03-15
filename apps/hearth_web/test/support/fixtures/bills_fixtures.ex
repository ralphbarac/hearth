defmodule HearthWeb.BillsFixtures do
  alias HearthBudget.Bills

  def valid_bill_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Bill #{System.unique_integer([:positive])}",
      "amount" => 1000,
      "frequency" => "monthly",
      "next_due_date" => "2026-04-01"
    })
  end

  def bill_fixture(scope, attrs \\ %{}) do
    {:ok, bill} = Bills.create_bill(scope, valid_bill_attributes(attrs))
    bill
  end
end
