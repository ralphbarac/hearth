defmodule HearthWeb.BudgetLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.BudgetFixtures

  describe "Budget page" do
    setup :register_and_log_in_user

    test "renders page header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budget")
      assert html =~ "Budget"
      assert html =~ "Add Transaction"
    end

    test "shows empty state with no transactions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budget")
      assert html =~ "No transactions this month"
    end

    test "shows existing transaction descriptions", %{conn: conn, scope: scope} do
      transaction_fixture(scope, %{
        "description" => "Rent Payment",
        "date" => Date.to_string(Date.utc_today())
      })

      {:ok, _view, html} = live(conn, ~p"/budget")
      assert html =~ "Rent Payment"
    end

    test "opens form on Add Transaction click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")

      view |> element("button", "Add Transaction") |> render_click()
      assert render(view) =~ "New Transaction"
    end

    test "creates transaction via form submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")

      view |> element("button", "Add Transaction") |> render_click()

      view
      |> form("form",
        transaction: %{
          description: "Coffee",
          amount_input: "4.50",
          type: "expense",
          date: Date.to_string(Date.utc_today())
        }
      )
      |> render_submit()

      assert render(view) =~ "Coffee"
    end

    test "shows validation errors on blank submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")

      view |> element("button", "Add Transaction") |> render_click()

      view
      |> form("form", transaction: %{description: "", amount_input: "", date: ""})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "month navigation changes displayed period", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/budget")

      today = Date.utc_today()
      current_month_label = Calendar.strftime(today, "%B %Y")
      assert html =~ current_month_label

      view |> element("button[phx-click='prev_month']") |> render_click()
      prev_date = Date.shift(Date.new!(today.year, today.month, 1), month: -1)
      assert render(view) =~ Calendar.strftime(prev_date, "%B %Y")
    end

    test "deletes transaction via delete button", %{conn: conn, scope: scope} do
      transaction =
        transaction_fixture(scope, %{
          "description" => "Transaction To Delete",
          "date" => Date.to_string(Date.utc_today())
        })

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert render(view) =~ transaction.description

      view
      |> element("[phx-click='delete_transaction'][phx-value-id='#{transaction.id}']")
      |> render_click()

      refute render(view) =~ transaction.description
    end
  end
end
