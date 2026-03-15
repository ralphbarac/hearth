defmodule HearthMaintenance.MaintenanceFixtures do
  import Hearth.AccountsFixtures

  alias HearthMaintenance.MaintenanceItems

  def valid_item_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Item #{System.unique_integer([:positive])}",
      "interval_days" => 30,
      "next_due_date" => Date.to_string(Date.utc_today())
    })
  end

  def maintenance_item_fixture(scope \\ user_scope_fixture(), attrs \\ %{}) do
    {:ok, item} = MaintenanceItems.create_item(scope, valid_item_attributes(attrs))
    item
  end
end
