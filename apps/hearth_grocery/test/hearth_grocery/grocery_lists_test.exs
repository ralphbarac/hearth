defmodule HearthGrocery.GroceryListsTest do
  use HearthGrocery.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthGrocery.GroceryFixtures

  alias HearthGrocery.GroceryLists
  alias HearthGrocery.GroceryList

  describe "list_grocery_lists/1" do
    test "returns empty list with no lists" do
      scope = user_scope_fixture()
      assert GroceryLists.list_grocery_lists(scope) == []
    end

    test "returns only own household's lists" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      list1 = grocery_list_fixture(scope1, %{"name" => "List A"})
      _list2 = grocery_list_fixture(scope2, %{"name" => "List B"})

      results = GroceryLists.list_grocery_lists(scope1)
      assert length(results) == 1
      assert hd(results).id == list1.id
    end

    test "returns multiple lists for household" do
      scope = user_scope_fixture()

      grocery_list_fixture(scope, %{"name" => "First"})
      grocery_list_fixture(scope, %{"name" => "Second"})

      results = GroceryLists.list_grocery_lists(scope)
      assert length(results) == 2
      names = Enum.map(results, & &1.name)
      assert "First" in names
      assert "Second" in names
    end
  end

  describe "create_grocery_list/2" do
    test "creates list with valid attrs" do
      scope = user_scope_fixture()
      attrs = valid_list_attributes(%{"name" => "My List"})

      assert {:ok, %GroceryList{} = list} = GroceryLists.create_grocery_list(scope, attrs)
      assert list.name == "My List"
      assert list.household_id == scope.household.id
      assert list.created_by_id == scope.user.id
    end

    test "returns error with missing name" do
      scope = user_scope_fixture()
      assert {:error, changeset} = GroceryLists.create_grocery_list(scope, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "sets household_id and created_by_id from scope" do
      scope = user_scope_fixture()
      {:ok, list} = GroceryLists.create_grocery_list(scope, valid_list_attributes())

      assert list.household_id == scope.household.id
      assert list.created_by_id == scope.user.id
    end
  end

  describe "update_grocery_list/3" do
    test "updates list with valid attrs" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)

      assert {:ok, updated} =
               GroceryLists.update_grocery_list(scope, list, %{"name" => "Updated Name"})

      assert updated.name == "Updated Name"
    end

    test "returns error with invalid attrs" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)

      assert {:error, changeset} = GroceryLists.update_grocery_list(scope, list, %{"name" => ""})
      assert %{name: [_ | _]} = errors_on(changeset)
    end
  end

  describe "delete_grocery_list/2" do
    test "removes list" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)

      assert {:ok, _} = GroceryLists.delete_grocery_list(scope, list)
      assert GroceryLists.list_grocery_lists(scope) == []
    end
  end

  describe "get_grocery_list!/2" do
    test "returns own list" do
      scope = user_scope_fixture()
      list = grocery_list_fixture(scope)

      assert fetched = GroceryLists.get_grocery_list!(scope, list.id)
      assert fetched.id == list.id
    end

    test "raises for another household's list" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      list = grocery_list_fixture(scope1)

      assert_raise Ecto.NoResultsError, fn ->
        GroceryLists.get_grocery_list!(scope2, list.id)
      end
    end
  end
end
