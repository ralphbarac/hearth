defmodule HearthInventory.InventoryItemsTest do
  use HearthInventory.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthInventory.InventoryFixtures

  alias HearthInventory.InventoryItems
  alias HearthInventory.InventoryItem

  describe "list_items/1" do
    test "returns empty list with no items" do
      scope = user_scope_fixture()
      assert InventoryItems.list_items(scope) == []
    end

    test "returns items ordered by name" do
      scope = user_scope_fixture()
      item_fixture(scope, %{"name" => "Zebra"})
      item_fixture(scope, %{"name" => "Apple"})
      item_fixture(scope, %{"name" => "Mango"})

      [i1, i2, i3] = InventoryItems.list_items(scope)
      assert i1.name == "Apple"
      assert i2.name == "Mango"
      assert i3.name == "Zebra"
    end

    test "isolates items by household" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      item_fixture(scope1, %{"name" => "Scope1 Item"})
      item_fixture(scope2, %{"name" => "Scope2 Item"})

      items1 = InventoryItems.list_items(scope1)
      items2 = InventoryItems.list_items(scope2)

      assert length(items1) == 1
      assert hd(items1).name == "Scope1 Item"
      assert length(items2) == 1
      assert hd(items2).name == "Scope2 Item"
    end
  end

  describe "list_low_stock_items/1" do
    test "returns items where quantity < min_quantity and min_quantity > 0" do
      scope = user_scope_fixture()
      item_fixture(scope, %{"name" => "Low Stock", "quantity" => 1, "min_quantity" => 5})

      low = InventoryItems.list_low_stock_items(scope)
      assert length(low) == 1
      assert hd(low).name == "Low Stock"
    end

    test "excludes items with adequate stock" do
      scope = user_scope_fixture()
      item_fixture(scope, %{"name" => "Adequate", "quantity" => 10, "min_quantity" => 5})

      assert InventoryItems.list_low_stock_items(scope) == []
    end

    test "excludes items with min_quantity == 0" do
      scope = user_scope_fixture()
      item_fixture(scope, %{"name" => "No Min", "quantity" => 0, "min_quantity" => 0})

      assert InventoryItems.list_low_stock_items(scope) == []
    end

    test "isolates low stock items by household" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      item_fixture(scope1, %{"name" => "Low", "quantity" => 1, "min_quantity" => 5})
      item_fixture(scope2, %{"name" => "Also Low", "quantity" => 1, "min_quantity" => 5})

      low1 = InventoryItems.list_low_stock_items(scope1)
      assert length(low1) == 1
      assert hd(low1).name == "Low"
    end
  end

  describe "create_item/2" do
    test "creates item with valid attrs" do
      scope = user_scope_fixture()
      attrs = valid_item_attributes(%{"name" => "Flour"})

      assert {:ok, %InventoryItem{} = item} = InventoryItems.create_item(scope, attrs)
      assert item.name == "Flour"
      assert item.household_id == scope.household.id
      assert item.created_by_id == scope.user.id
    end

    test "returns error when name is missing" do
      scope = user_scope_fixture()
      assert {:error, changeset} = InventoryItems.create_item(scope, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "quantity defaults to 0" do
      scope = user_scope_fixture()
      {:ok, item} = InventoryItems.create_item(scope, %{"name" => "Salt"})
      assert item.quantity == 0
    end

    test "min_quantity defaults to 0" do
      scope = user_scope_fixture()
      {:ok, item} = InventoryItems.create_item(scope, %{"name" => "Pepper"})
      assert item.min_quantity == 0
    end

    test "returns error when quantity is negative" do
      scope = user_scope_fixture()
      attrs = valid_item_attributes(%{"quantity" => -1})
      assert {:error, changeset} = InventoryItems.create_item(scope, attrs)
      assert %{quantity: [_]} = errors_on(changeset)
    end

    test "returns error when min_quantity is negative" do
      scope = user_scope_fixture()
      attrs = valid_item_attributes(%{"min_quantity" => -1})
      assert {:error, changeset} = InventoryItems.create_item(scope, attrs)
      assert %{min_quantity: [_]} = errors_on(changeset)
    end
  end

  describe "update_item/3" do
    test "updates item with valid attrs" do
      scope = user_scope_fixture()
      item = item_fixture(scope, %{"name" => "Original"})

      assert {:ok, updated} = InventoryItems.update_item(scope, item, %{"name" => "Updated"})
      assert updated.name == "Updated"
    end

    test "returns error with invalid attrs" do
      scope = user_scope_fixture()
      item = item_fixture(scope)

      assert {:error, changeset} = InventoryItems.update_item(scope, item, %{"name" => ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_item/2" do
    test "removes item from list" do
      scope = user_scope_fixture()
      item = item_fixture(scope)

      assert {:ok, _} = InventoryItems.delete_item(scope, item)
      assert InventoryItems.list_items(scope) == []
    end
  end

  describe "get_item!/2" do
    test "returns own item" do
      scope = user_scope_fixture()
      item = item_fixture(scope)

      found = InventoryItems.get_item!(scope, item.id)
      assert found.id == item.id
    end

    test "raises for item belonging to another household" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      item = item_fixture(scope1)

      assert_raise Ecto.NoResultsError, fn ->
        InventoryItems.get_item!(scope2, item.id)
      end
    end
  end

  describe "adjust_quantity/3" do
    test "increments quantity" do
      scope = user_scope_fixture()
      item = item_fixture(scope, %{"quantity" => 5})

      assert {:ok, updated} = InventoryItems.adjust_quantity(scope, item, 3)
      assert updated.quantity == 8
    end

    test "decrements quantity" do
      scope = user_scope_fixture()
      item = item_fixture(scope, %{"quantity" => 5})

      assert {:ok, updated} = InventoryItems.adjust_quantity(scope, item, -2)
      assert updated.quantity == 3
    end

    test "clamps at zero, never goes negative" do
      scope = user_scope_fixture()
      item = item_fixture(scope, %{"quantity" => 2})

      assert {:ok, updated} = InventoryItems.adjust_quantity(scope, item, -10)
      assert updated.quantity == 0
    end
  end
end
