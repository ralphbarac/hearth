defmodule HearthChores.ChoresTest do
  use HearthChores.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthChores.ChoresFixtures

  alias HearthChores.Chores
  alias HearthChores.Chore

  setup do
    scope = user_scope_fixture()
    {:ok, scope: scope}
  end

  describe "list_chores/1" do
    test "returns all chores for household", %{scope: scope} do
      chore = chore_fixture(scope)
      assert Enum.any?(Chores.list_chores(scope), &(&1.id == chore.id))
    end

    test "does not return chores from other households" do
      other = user_scope_fixture()
      chore = chore_fixture(other)
      scope = user_scope_fixture()
      refute Enum.any?(Chores.list_chores(scope), &(&1.id == chore.id))
    end
  end

  describe "create_chore/2" do
    test "creates chore with valid attrs", %{scope: scope} do
      attrs = valid_chore_attributes(%{"name" => "Mow lawn", "frequency" => "weekly"})
      assert {:ok, %Chore{} = chore} = Chores.create_chore(scope, attrs)
      assert chore.name == "Mow lawn"
      assert chore.frequency == "weekly"
    end

    test "returns error on missing name", %{scope: scope} do
      assert {:error, changeset} = Chores.create_chore(scope, %{"frequency" => "weekly", "next_due_date" => Date.utc_today()})
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "rejects invalid frequency", %{scope: scope} do
      attrs = valid_chore_attributes(%{"frequency" => "yearly"})
      assert {:error, changeset} = Chores.create_chore(scope, attrs)
      assert %{frequency: [_ | _]} = errors_on(changeset)
    end
  end

  describe "complete_chore/3" do
    test "advances next_due_date for weekly chore", %{scope: scope} do
      today = Date.utc_today()
      chore = chore_fixture(scope, %{"frequency" => "weekly", "next_due_date" => Date.to_string(today)})
      assert {:ok, updated} = Chores.complete_chore(scope, chore)
      assert updated.next_due_date == Date.add(today, 7)
      assert updated.is_active == true
    end

    test "advances next_due_date for monthly chore", %{scope: scope} do
      today = Date.utc_today()
      chore = chore_fixture(scope, %{"frequency" => "monthly", "next_due_date" => Date.to_string(today)})
      assert {:ok, updated} = Chores.complete_chore(scope, chore)
      assert updated.next_due_date == Date.shift(today, month: 1)
    end

    test "sets is_active false for once chore", %{scope: scope} do
      chore = chore_fixture(scope, %{"frequency" => "once"})
      assert {:ok, updated} = Chores.complete_chore(scope, chore)
      assert updated.is_active == false
    end

    test "advances biweekly by 14 days", %{scope: scope} do
      today = Date.utc_today()
      chore = chore_fixture(scope, %{"frequency" => "biweekly", "next_due_date" => Date.to_string(today)})
      assert {:ok, updated} = Chores.complete_chore(scope, chore)
      assert updated.next_due_date == Date.add(today, 14)
    end
  end

  describe "delete_chore/2" do
    test "deletes chore", %{scope: scope} do
      chore = chore_fixture(scope)
      assert {:ok, _} = Chores.delete_chore(scope, chore)
      assert Chores.list_chores(scope) == []
    end
  end
end
