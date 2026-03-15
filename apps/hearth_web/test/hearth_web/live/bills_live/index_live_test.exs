defmodule HearthWeb.BillsLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.BillsFixtures

  describe "Bills page" do
    setup :register_and_log_in_user

    test "renders page header as Recurring", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bills")
      assert html =~ "Recurring"
      assert html =~ "Add Bill"
    end

    test "shows empty state with no bills", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bills")
      assert html =~ "No active bills"
    end

    test "shows existing bill", %{conn: conn, scope: scope} do
      bill_fixture(scope, %{"name" => "Netflix Subscription"})
      {:ok, _view, html} = live(conn, ~p"/bills")
      assert html =~ "Netflix Subscription"
    end

    test "expense bill appears in Active Expenses section with Mark Paid button", %{conn: conn, scope: scope} do
      bill_fixture(scope, %{"name" => "Rent", "type" => "expense"})
      {:ok, _view, html} = live(conn, ~p"/bills")
      assert html =~ "Active Expenses"
      assert html =~ "Rent"
      assert html =~ "Mark Paid"
    end

    test "income bill appears in Active Income section with Mark Received button", %{conn: conn, scope: scope} do
      bill_fixture(scope, %{"name" => "Paycheck", "type" => "income"})
      {:ok, _view, html} = live(conn, ~p"/bills")
      assert html =~ "Active Income"
      assert html =~ "Paycheck"
      assert html =~ "Mark Received"
    end

    test "opens form on Add Bill click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bills")
      view |> element("button", "Add Bill") |> render_click()
      assert render(view) =~ "New Bill"
    end

    test "creates bill via form submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bills")

      view |> element("button", "Add Bill") |> render_click()

      view
      |> form("form",
        bill: %{
          name: "Rent",
          amount_input: "1200.00",
          frequency: "monthly",
          next_due_date: "2026-04-01"
        }
      )
      |> render_submit()

      assert render(view) =~ "Rent"
    end

    test "shows validation errors on blank submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bills")

      view |> element("button", "Add Bill") |> render_click()

      view
      |> form("form", bill: %{name: "", amount_input: "", next_due_date: ""})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "edits bill via edit button", %{conn: conn, scope: scope} do
      bill = bill_fixture(scope, %{"name" => "Old Name"})
      {:ok, view, _html} = live(conn, ~p"/bills")

      view
      |> element("[phx-click='edit_bill'][phx-value-id='#{bill.id}']")
      |> render_click()

      assert render(view) =~ "Edit Bill"

      view
      |> form("form", bill: %{name: "New Name"})
      |> render_submit()

      assert render(view) =~ "New Name"
    end

    test "deletes bill via delete button", %{conn: conn, scope: scope} do
      bill = bill_fixture(scope, %{"name" => "Bill To Delete"})
      {:ok, view, _html} = live(conn, ~p"/bills")
      assert render(view) =~ "Bill To Delete"

      view
      |> element("[phx-click='delete_bill'][phx-value-id='#{bill.id}']")
      |> render_click()

      refute render(view) =~ "Bill To Delete"
    end

    test "mark paid advances due date", %{conn: conn, scope: scope} do
      bill =
        bill_fixture(scope, %{
          "name" => "Gym Membership",
          "frequency" => "monthly",
          "next_due_date" => "2026-04-01"
        })

      {:ok, view, _html} = live(conn, ~p"/bills")
      assert render(view) =~ "2026-04-01"

      view
      |> element("[phx-click='mark_paid'][phx-value-id='#{bill.id}']")
      |> render_click()

      assert render(view) =~ "2026-05-01"
    end

    test "can create a bi_weekly bill via form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bills")

      view |> element("button", "Add Bill") |> render_click()

      view
      |> form("form",
        bill: %{
          name: "Bi-weekly Cleaning",
          amount_input: "80.00",
          type: "expense",
          frequency: "bi_weekly",
          next_due_date: "2026-04-01"
        }
      )
      |> render_submit()

      assert render(view) =~ "Bi-weekly Cleaning"
    end

    test "can create an income bill via form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bills")

      view |> element("button", "Add Bill") |> render_click()

      view
      |> form("form",
        bill: %{
          name: "Monthly Salary",
          amount_input: "5000.00",
          type: "income",
          frequency: "monthly",
          next_due_date: "2026-04-30"
        }
      )
      |> render_submit()

      assert render(view) =~ "Monthly Salary"
      assert render(view) =~ "Active Income"
    end
  end
end
