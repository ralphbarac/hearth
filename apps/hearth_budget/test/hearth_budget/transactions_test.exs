defmodule HearthBudget.TransactionsTest do
  use HearthBudget.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthBudget.BudgetFixtures

  alias HearthBudget.Transactions
  alias HearthBudget.Transaction

  describe "list_transactions/1" do
    test "returns empty list with no transactions" do
      scope = user_scope_fixture()
      assert Transactions.list_transactions(scope) == []
    end

    test "returns only own household's transactions" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      t1 = transaction_fixture(scope1)
      _t2 = transaction_fixture(scope2)

      results = Transactions.list_transactions(scope1)
      assert length(results) == 1
      assert hd(results).id == t1.id
    end

    test "returns transactions ordered by date desc" do
      scope = user_scope_fixture()

      _older = transaction_fixture(scope, %{"date" => "2026-03-01", "description" => "Older"})
      _newer = transaction_fixture(scope, %{"date" => "2026-03-10", "description" => "Newer"})

      [first, second] = Transactions.list_transactions(scope)
      assert first.description == "Newer"
      assert second.description == "Older"
    end
  end

  describe "list_transactions_for_month/2" do
    test "returns only transactions in the given month" do
      scope = user_scope_fixture()

      _in_month =
        transaction_fixture(scope, %{"date" => "2026-03-15", "description" => "In March"})

      _out_of_month =
        transaction_fixture(scope, %{"date" => "2026-04-01", "description" => "In April"})

      results = Transactions.list_transactions_for_month(scope, {2026, 3})
      assert length(results) == 1
      assert hd(results).description == "In March"
    end
  end

  describe "create_transaction/2" do
    test "creates transaction with valid attrs" do
      scope = user_scope_fixture()
      attrs = valid_transaction_attributes(%{"description" => "Groceries"})

      assert {:ok, %Transaction{} = t} = Transactions.create_transaction(scope, attrs)
      assert t.description == "Groceries"
      assert t.household_id == scope.household.id
      assert t.created_by_id == scope.user.id
    end

    test "returns error with missing required fields" do
      scope = user_scope_fixture()
      assert {:error, changeset} = Transactions.create_transaction(scope, %{})
      errors = errors_on(changeset)
      assert errors[:type]
      assert errors[:date]
    end

    test "returns error with invalid type" do
      scope = user_scope_fixture()
      attrs = valid_transaction_attributes(%{"type" => "invalid"})
      assert {:error, changeset} = Transactions.create_transaction(scope, attrs)
      assert errors_on(changeset)[:type]
    end

    test "returns error when amount is zero" do
      scope = user_scope_fixture()
      attrs = valid_transaction_attributes(%{"amount" => 0})
      assert {:error, changeset} = Transactions.create_transaction(scope, attrs)
      assert errors_on(changeset)[:amount]
    end
  end

  describe "update_transaction/3" do
    test "updates transaction with valid attrs" do
      scope = user_scope_fixture()
      t = transaction_fixture(scope)

      assert {:ok, updated} =
               Transactions.update_transaction(scope, t, %{"description" => "Updated"})

      assert updated.description == "Updated"
    end

    test "returns error with invalid attrs" do
      scope = user_scope_fixture()
      t = transaction_fixture(scope)

      assert {:error, changeset} = Transactions.update_transaction(scope, t, %{"type" => "bad"})
      assert errors_on(changeset)[:type]
    end
  end

  describe "delete_transaction/2" do
    test "removes transaction from list" do
      scope = user_scope_fixture()
      t = transaction_fixture(scope)

      assert {:ok, _} = Transactions.delete_transaction(scope, t)
      assert Transactions.list_transactions(scope) == []
    end
  end

  describe "get_transaction!/2" do
    test "returns own transaction" do
      scope = user_scope_fixture()
      t = transaction_fixture(scope)

      assert fetched = Transactions.get_transaction!(scope, t.id)
      assert fetched.id == t.id
    end

    test "raises for another household's transaction" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      t = transaction_fixture(scope1)

      assert_raise Ecto.NoResultsError, fn ->
        Transactions.get_transaction!(scope2, t.id)
      end
    end
  end

  describe "spending_by_category/2" do
    test "returns empty list with no expenses" do
      scope = user_scope_fixture()
      assert Transactions.spending_by_category(scope, {2026, 3}) == []
    end

    test "excludes income transactions" do
      scope = user_scope_fixture()
      transaction_fixture(scope, %{"type" => "income", "amount" => 5000, "date" => "2026-03-01"})
      assert Transactions.spending_by_category(scope, {2026, 3}) == []
    end

    test "groups categorised expenses and sums totals" do
      scope = user_scope_fixture()
      cat = category_fixture(scope, %{name: "Food", type: "expense"})

      transaction_fixture(scope, %{
        "category_id" => cat.id,
        "amount" => 1000,
        "type" => "expense",
        "date" => "2026-03-01"
      })

      transaction_fixture(scope, %{
        "category_id" => cat.id,
        "amount" => 500,
        "type" => "expense",
        "date" => "2026-03-10"
      })

      [item] = Transactions.spending_by_category(scope, {2026, 3})
      assert item.name == "Food"
      assert item.total == 1500
    end

    test "groups uncategorised expenses as Other" do
      scope = user_scope_fixture()
      transaction_fixture(scope, %{"amount" => 2000, "type" => "expense", "date" => "2026-03-05"})

      [item] = Transactions.spending_by_category(scope, {2026, 3})
      assert item.name == "Other"
      assert item.total == 2000
    end

    test "sorts by total descending" do
      scope = user_scope_fixture()
      cat1 = category_fixture(scope, %{name: "Small", icon: "💰", type: "expense"})
      cat2 = category_fixture(scope, %{name: "Big", icon: "💸", type: "expense"})

      transaction_fixture(scope, %{
        "category_id" => cat1.id,
        "amount" => 100,
        "type" => "expense",
        "date" => "2026-03-01"
      })

      transaction_fixture(scope, %{
        "category_id" => cat2.id,
        "amount" => 5000,
        "type" => "expense",
        "date" => "2026-03-01"
      })

      [first, second] = Transactions.spending_by_category(scope, {2026, 3})
      assert first.name == "Big"
      assert second.name == "Small"
    end

    test "ignores other households' transactions" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      transaction_fixture(scope2, %{"amount" => 9999, "type" => "expense", "date" => "2026-03-01"})

      assert Transactions.spending_by_category(scope1, {2026, 3}) == []
    end
  end

  describe "monthly_summaries/2" do
    test "returns n entries oldest-first ending with current month" do
      scope = user_scope_fixture()
      result = Transactions.monthly_summaries(scope, 6)

      assert length(result) == 6

      today = Date.utc_today()
      last = List.last(result)
      assert last.label == Calendar.strftime(Date.new!(today.year, today.month, 1), "%b %y")
    end

    test "returns zero totals for empty months" do
      scope = user_scope_fixture()
      [summary] = Transactions.monthly_summaries(scope, 1)
      assert summary.income == 0
      assert summary.expenses == 0
    end

    test "sums income and expenses in current month" do
      scope = user_scope_fixture()
      today = Date.utc_today()
      date_str = Date.to_string(today)

      transaction_fixture(scope, %{"type" => "income", "amount" => 3000, "date" => date_str})
      transaction_fixture(scope, %{"type" => "expense", "amount" => 1500, "date" => date_str})

      [summary] = Transactions.monthly_summaries(scope, 1)
      assert summary.income == 3000
      assert summary.expenses == 1500
    end
  end

  describe "monthly_summary/2" do
    test "returns zero totals with no transactions" do
      scope = user_scope_fixture()
      summary = Transactions.monthly_summary(scope, {2026, 3})
      assert summary == %{income: 0, expenses: 0, net: 0}
    end

    test "sums income and expenses correctly" do
      scope = user_scope_fixture()

      transaction_fixture(scope, %{"type" => "income", "amount" => 5000, "date" => "2026-03-01"})
      transaction_fixture(scope, %{"type" => "expense", "amount" => 2000, "date" => "2026-03-15"})
      transaction_fixture(scope, %{"type" => "expense", "amount" => 500, "date" => "2026-03-20"})

      summary = Transactions.monthly_summary(scope, {2026, 3})
      assert summary.income == 5000
      assert summary.expenses == 2500
      assert summary.net == 2500
    end

    test "ignores transactions from other months" do
      scope = user_scope_fixture()

      transaction_fixture(scope, %{"type" => "income", "amount" => 5000, "date" => "2026-02-28"})
      transaction_fixture(scope, %{"type" => "expense", "amount" => 1000, "date" => "2026-03-01"})

      summary = Transactions.monthly_summary(scope, {2026, 3})
      assert summary.income == 0
      assert summary.expenses == 1000
      assert summary.net == -1000
    end
  end
end
