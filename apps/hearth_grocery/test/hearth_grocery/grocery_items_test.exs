defmodule HearthGrocery.GroceryItemsTest do
  use HearthGrocery.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthGrocery.GroceryFixtures

  alias HearthGrocery.GroceryItems
  alias HearthGrocery.GroceryItem

  describe "list_items/2" do
    test "returns empty list with no items" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)
      assert GroceryItems.list_items(scope, list) == []
    end

    test "returns items ordered by position asc" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)

      item1 = grocery_item_fixture(scope, list, %{"name" => "First"})
      item2 = grocery_item_fixture(scope, list, %{"name" => "Second"})
      item3 = grocery_item_fixture(scope, list, %{"name" => "Third"})

      [i1, i2, i3] = GroceryItems.list_items(scope, list)
      assert i1.id == item1.id
      assert i2.id == item2.id
      assert i3.id == item3.id
    end
  end

  describe "create_item/3" do
    test "creates item with valid attrs" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)
      attrs = valid_item_attributes(%{"name" => "Milk"})

      assert {:ok, %GroceryItem{} = item} = GroceryItems.create_item(scope, list, attrs)
      assert item.name == "Milk"
      assert item.list_id == list.id
      assert item.added_by_id == scope.user.id
    end

    test "returns error with missing name" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)
      assert {:error, changeset} = GroceryItems.create_item(scope, list, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "auto-assigns incrementing position" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)

      {:ok, item1} = GroceryItems.create_item(scope, list, valid_item_attributes())
      {:ok, item2} = GroceryItems.create_item(scope, list, valid_item_attributes())
      {:ok, item3} = GroceryItems.create_item(scope, list, valid_item_attributes())

      assert item1.position < item2.position
      assert item2.position < item3.position
    end
  end

  describe "toggle_checked/2" do
    test "flips checked from false to true" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)
      item = grocery_item_fixture(scope, list)

      assert item.checked == false
      assert {:ok, toggled} = GroceryItems.toggle_checked(scope, item)
      assert toggled.checked == true
    end

    test "flips checked from true to false" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)
      item = grocery_item_fixture(scope, list)
      {:ok, checked_item} = GroceryItems.toggle_checked(scope, item)

      assert {:ok, unchecked} = GroceryItems.toggle_checked(scope, checked_item)
      assert unchecked.checked == false
    end
  end

  describe "delete_item/2" do
    test "removes item" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)
      item = grocery_item_fixture(scope, list)

      assert {:ok, _} = GroceryItems.delete_item(scope, item)
      assert GroceryItems.list_items(scope, list) == []
    end
  end
end
