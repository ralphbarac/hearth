defmodule HearthBudget.BillsTest do
  use HearthBudget.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthBudget.BillsFixtures

  alias HearthBudget.Bills
  alias HearthBudget.Bill
  alias HearthBudget.Transactions

  describe "list_bills/1" do
    test "returns empty list with no bills" do
      scope = user_scope_fixture()
      assert Bills.list_bills(scope) == []
    end

    test "returns only own household's bills" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      b1 = bill_fixture(scope1)
      _b2 = bill_fixture(scope2)

      results = Bills.list_bills(scope1)
      assert length(results) == 1
      assert hd(results).id == b1.id
    end
  end

  describe "list_bills_due_soon/2" do
    test "returns bills due within the given days" do
      scope = user_scope_fixture()
      today = Date.utc_today()

      _due_soon = bill_fixture(scope, %{"next_due_date" => Date.to_string(Date.add(today, 3))})
      _due_later = bill_fixture(scope, %{"next_due_date" => Date.to_string(Date.add(today, 30))})

      results = Bills.list_bills_due_soon(scope, 7)
      assert length(results) == 1
    end

    test "excludes inactive bills" do
      scope = user_scope_fixture()
      today = Date.utc_today()

      _inactive =
        bill_fixture(scope, %{
          "next_due_date" => Date.to_string(Date.add(today, 3)),
          "is_active" => false
        })

      assert Bills.list_bills_due_soon(scope, 7) == []
    end

    test "returns bills due today" do
      scope = user_scope_fixture()
      today = Date.utc_today()

      _due_today = bill_fixture(scope, %{"next_due_date" => Date.to_string(today)})

      results = Bills.list_bills_due_soon(scope, 0)
      assert length(results) == 1
    end

    test "excludes other household's bills" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      today = Date.utc_today()

      _bill = bill_fixture(scope2, %{"next_due_date" => Date.to_string(Date.add(today, 3))})

      assert Bills.list_bills_due_soon(scope1, 7) == []
    end
  end

  describe "create_bill/2" do
    test "creates bill with valid attrs" do
      scope = user_scope_fixture()
      attrs = valid_bill_attributes(%{"name" => "Netflix"})

      assert {:ok, %Bill{} = bill} = Bills.create_bill(scope, attrs)
      assert bill.name == "Netflix"
      assert bill.household_id == scope.household.id
      assert bill.created_by_id == scope.user.id
    end

    test "defaults type to expense" do
      scope = user_scope_fixture()
      attrs = valid_bill_attributes()

      assert {:ok, bill} = Bills.create_bill(scope, attrs)
      assert bill.type == "expense"
    end

    test "accepts income type" do
      scope = user_scope_fixture()
      attrs = valid_bill_attributes(%{"type" => "income"})

      assert {:ok, bill} = Bills.create_bill(scope, attrs)
      assert bill.type == "income"
    end

    test "rejects invalid type" do
      scope = user_scope_fixture()
      attrs = valid_bill_attributes(%{"type" => "transfer"})
      assert {:error, changeset} = Bills.create_bill(scope, attrs)
      assert errors_on(changeset)[:type]
    end

    test "returns error with missing required fields" do
      scope = user_scope_fixture()
      assert {:error, changeset} = Bills.create_bill(scope, %{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:frequency]
      assert errors[:next_due_date]
    end

    test "returns error with invalid frequency" do
      scope = user_scope_fixture()
      attrs = valid_bill_attributes(%{"frequency" => "invalid"})
      assert {:error, changeset} = Bills.create_bill(scope, attrs)
      assert errors_on(changeset)[:frequency]
    end

    test "returns error when name exceeds 100 characters" do
      scope = user_scope_fixture()
      attrs = valid_bill_attributes(%{"name" => String.duplicate("a", 101)})
      assert {:error, changeset} = Bills.create_bill(scope, attrs)
      assert "should be at most 100 character(s)" in errors_on(changeset).name
    end

    test "returns error when amount is zero" do
      scope = user_scope_fixture()
      attrs = valid_bill_attributes(%{"amount" => 0})
      assert {:error, changeset} = Bills.create_bill(scope, attrs)
      assert errors_on(changeset)[:amount]
    end

    test "converts amount_input string to cents" do
      scope = user_scope_fixture()
      attrs = valid_bill_attributes(%{"amount_input" => "12.99"})

      assert {:ok, bill} = Bills.create_bill(scope, attrs)
      assert bill.amount == 1299
    end
  end

  describe "update_bill/3" do
    test "updates bill with valid attrs" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope)

      assert {:ok, updated} = Bills.update_bill(scope, bill, %{"name" => "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "returns error with invalid attrs" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope)

      assert {:error, changeset} = Bills.update_bill(scope, bill, %{"frequency" => "bad"})
      assert errors_on(changeset)[:frequency]
    end
  end

  describe "delete_bill/2" do
    test "removes bill" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope)

      assert {:ok, _} = Bills.delete_bill(scope, bill)
      assert Bills.list_bills(scope) == []
    end
  end

  describe "get_bill!/2" do
    test "returns own bill" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope)

      assert fetched = Bills.get_bill!(scope, bill.id)
      assert fetched.id == bill.id
    end

    test "raises for another household's bill" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      bill = bill_fixture(scope1)

      assert_raise Ecto.NoResultsError, fn ->
        Bills.get_bill!(scope2, bill.id)
      end
    end
  end

  describe "mark_paid/2" do
    test "advances next_due_date weekly" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope, %{"frequency" => "weekly", "next_due_date" => "2026-04-01"})

      {:ok, updated} = Bills.mark_paid(scope, bill)
      assert updated.next_due_date == ~D[2026-04-08]
    end

    test "advances next_due_date bi_weekly by 14 days" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope, %{"frequency" => "bi_weekly", "next_due_date" => "2026-04-01"})

      {:ok, updated} = Bills.mark_paid(scope, bill)
      assert updated.next_due_date == ~D[2026-04-15]
    end

    test "advances next_due_date monthly" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope, %{"frequency" => "monthly", "next_due_date" => "2026-04-01"})

      {:ok, updated} = Bills.mark_paid(scope, bill)
      assert updated.next_due_date == ~D[2026-05-01]
    end

    test "advances next_due_date quarterly" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope, %{"frequency" => "quarterly", "next_due_date" => "2026-04-01"})

      {:ok, updated} = Bills.mark_paid(scope, bill)
      assert updated.next_due_date == ~D[2026-07-01]
    end

    test "advances next_due_date yearly" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope, %{"frequency" => "yearly", "next_due_date" => "2026-04-01"})

      {:ok, updated} = Bills.mark_paid(scope, bill)
      assert updated.next_due_date == ~D[2027-04-01]
    end

    test "auto_create_transaction creates an expense transaction" do
      scope = user_scope_fixture()

      bill =
        bill_fixture(scope, %{
          "name" => "Rent",
          "amount" => 150_000,
          "auto_create_transaction" => true
        })

      {:ok, _updated_bill} = Bills.mark_paid(scope, bill)

      transactions = Transactions.list_transactions(scope)
      assert length(transactions) == 1
      assert hd(transactions).amount == 150_000
      assert hd(transactions).type == "expense"
    end

    test "auto_create_transaction for income bill creates an income transaction" do
      scope = user_scope_fixture()

      bill =
        bill_fixture(scope, %{
          "name" => "Paycheck",
          "amount" => 300_000,
          "type" => "income",
          "auto_create_transaction" => true
        })

      {:ok, _updated_bill} = Bills.mark_paid(scope, bill)

      transactions = Transactions.list_transactions(scope)
      assert length(transactions) == 1
      assert hd(transactions).amount == 300_000
      assert hd(transactions).type == "income"
    end

    test "does not create transaction when auto_create_transaction is false" do
      scope = user_scope_fixture()
      bill = bill_fixture(scope, %{"auto_create_transaction" => false})

      {:ok, _} = Bills.mark_paid(scope, bill)
      assert Transactions.list_transactions(scope) == []
    end
  end
end
