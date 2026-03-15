defmodule HearthInventory.InventoryFixtures do
  alias HearthInventory.InventoryItems

  def valid_item_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Item #{System.unique_integer([:positive])}",
      "quantity" => 5,
      "min_quantity" => 2
    })
  end

  def item_fixture(scope, attrs \\ %{}) do
    {:ok, item} = InventoryItems.create_item(scope, valid_item_attributes(attrs))
    item
  end
end
