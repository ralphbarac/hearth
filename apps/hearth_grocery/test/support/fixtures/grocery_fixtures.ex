defmodule HearthGrocery.GroceryFixtures do
  alias HearthGrocery.GroceryLists
  alias HearthGrocery.GroceryItems

  def valid_list_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test List #{System.unique_integer([:positive])}"
    })
  end

  def grocery_list_fixture(scope, attrs \\ %{}) do
    {:ok, list} = GroceryLists.create_grocery_list(scope, valid_list_attributes(attrs))
    list
  end

  def valid_item_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Item #{System.unique_integer([:positive])}"
    })
  end

  def grocery_item_fixture(scope, list, attrs \\ %{}) do
    {:ok, item} = GroceryItems.create_item(scope, list, valid_item_attributes(attrs))
    item
  end
end
