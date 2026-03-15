defmodule HearthMaintenance.MaintenanceItemsTest do
  use HearthMaintenance.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthMaintenance.MaintenanceFixtures

  alias HearthMaintenance.MaintenanceItems
  alias HearthMaintenance.MaintenanceItem

  setup do
    scope = user_scope_fixture()
    {:ok, scope: scope}
  end

  describe "list_items/1" do
    test "returns all items for household", %{scope: scope} do
      item = maintenance_item_fixture(scope)
      assert Enum.any?(MaintenanceItems.list_items(scope), &(&1.id == item.id))
    end

    test "does not return items from other households" do
      other = user_scope_fixture()
      item = maintenance_item_fixture(other)
      scope = user_scope_fixture()
      refute Enum.any?(MaintenanceItems.list_items(scope), &(&1.id == item.id))
    end
  end

  describe "create_item/2" do
    test "creates item with valid attrs", %{scope: scope} do
      attrs = valid_item_attributes(%{"name" => "HVAC Filter", "interval_days" => 90})
      assert {:ok, %MaintenanceItem{} = item} = MaintenanceItems.create_item(scope, attrs)
      assert item.name == "HVAC Filter"
      assert item.interval_days == 90
    end

    test "returns error on missing required fields", %{scope: scope} do
      assert {:error, changeset} = MaintenanceItems.create_item(scope, %{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :name)
    end

    test "rejects interval_days <= 0", %{scope: scope} do
      attrs = valid_item_attributes(%{"interval_days" => 0})
      assert {:error, changeset} = MaintenanceItems.create_item(scope, attrs)
      assert %{interval_days: [_ | _]} = errors_on(changeset)
    end
  end

  describe "log_maintenance/3" do
    test "creates record and advances next_due_date", %{scope: scope} do
      today = Date.utc_today()
      item = maintenance_item_fixture(scope, %{"interval_days" => 30, "next_due_date" => Date.to_string(today)})

      assert {:ok, updated} = MaintenanceItems.log_maintenance(scope, item, %{"performed_on" => Date.to_string(today)})
      assert updated.next_due_date == Date.add(today, 30)
    end

    test "history records are returned in descending order", %{scope: scope} do
      today = Date.utc_today()
      item = maintenance_item_fixture(scope)

      MaintenanceItems.log_maintenance(scope, item, %{"performed_on" => Date.to_string(Date.add(today, -10))})
      item = MaintenanceItems.get_item!(scope, item.id)
      MaintenanceItems.log_maintenance(scope, item, %{"performed_on" => Date.to_string(today)})
      item = MaintenanceItems.get_item!(scope, item.id)

      records = MaintenanceItems.list_records(scope, item)
      assert length(records) == 2
      [first | _] = records
      assert first.performed_on == today
    end
  end

  describe "delete_item/2" do
    test "deletes item", %{scope: scope} do
      item = maintenance_item_fixture(scope)
      assert {:ok, _} = MaintenanceItems.delete_item(scope, item)
      assert MaintenanceItems.list_items(scope) == []
    end
  end
end
