defmodule HearthWeb.CalendarLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.CalendarFixtures
  import HearthWeb.GroceryFixtures
  import HearthWeb.BudgetFixtures

  describe "Calendar page" do
    setup :register_and_log_in_user

    test "renders calendar grid with month navigation", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/calendar")
      assert html =~ "Calendar"
      assert html =~ "Sun"
      assert html =~ "Mon"
    end

    test "shows existing event titles as chips", %{conn: conn, scope: scope} do
      event = event_fixture(scope, %{"title" => "Team Meeting"})

      {:ok, _view, html} = live(conn, ~p"/calendar")
      assert html =~ event.title
    end

    test "opens form on Add click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/calendar")

      view |> element("button[phx-click='new_event']") |> render_click()
      assert render(view) =~ "New Event"
    end

    test "creates event via form submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/calendar")

      view |> element("button[phx-click='new_event']") |> render_click()

      today = Date.utc_today()
      starts_at = "#{today.year}-#{String.pad_leading(to_string(today.month), 2, "0")}-20T18:00"

      view
      |> form("form",
        event: %{
          title: "Birthday Party",
          starts_at: starts_at
        }
      )
      |> render_submit()

      assert render(view) =~ "Birthday Party"
    end

    test "shows validation errors on blank submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/calendar")

      view |> element("button[phx-click='new_event']") |> render_click()

      view
      |> form("form", event: %{title: "", starts_at: ""})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "deletes event via delete button in day detail", %{conn: conn, scope: scope} do
      event = event_fixture(scope, %{"title" => "Event To Delete"})

      {:ok, view, _html} = live(conn, ~p"/calendar")
      assert render(view) =~ event.title

      date_str = DateTime.to_date(event.starts_at) |> Date.to_iso8601()
      view |> element("[phx-click='select_date'][phx-value-date='#{date_str}']") |> render_click()

      view
      |> element("[phx-click='delete_event'][phx-value-id='#{event.id}']")
      |> render_click()

      refute render(view) =~ event.title
    end
  end

  describe "recurring events" do
    setup :register_and_log_in_user

    test "recurring event title appears multiple times in calendar grid", %{
      conn: conn,
      scope: scope
    } do
      recurring_event_fixture(scope, %{"title" => "Weekly Standup"})

      {:ok, _view, html} = live(conn, ~p"/calendar")

      occurrences = html |> String.split("Weekly Standup") |> length() |> Kernel.-(1)
      assert occurrences >= 2, "Expected at least 2 occurrences, got #{occurrences}"
    end

    test "clicking recurring event in day panel shows recurrence modal", %{
      conn: conn,
      scope: scope
    } do
      recurring_event_fixture(scope, %{"title" => "Weekly Meeting"})

      {:ok, view, _html} = live(conn, ~p"/calendar")
      refute render(view) =~ "modal-open"

      today = Date.utc_today()
      date_str = Date.to_iso8601(%{today | day: 1})
      view |> element("[phx-click='select_date'][phx-value-date='#{date_str}']") |> render_click()
      view |> element("[phx-click='show_recurrence_modal']") |> render_click()

      assert render(view) =~ "modal-open"
      assert render(view) =~ "Recurring event"
    end

    test "delete this occurrence removes one occurrence but not others", %{
      conn: conn,
      scope: scope
    } do
      recurring_event_fixture(scope, %{"title" => "Weekly Sync"})

      {:ok, view, _html} = live(conn, ~p"/calendar")

      today = Date.utc_today()
      date_str = Date.to_iso8601(%{today | day: 1})
      view |> element("[phx-click='select_date'][phx-value-date='#{date_str}']") |> render_click()
      view |> element("[phx-click='show_recurrence_modal_delete']") |> render_click()
      assert render(view) =~ "modal-open"

      view |> element("[phx-click='recurrence_delete_occurrence']") |> render_click()

      html = render(view)
      assert html =~ "Weekly Sync"
      refute html =~ "modal-open"
    end

    test "delete entire series removes all occurrences", %{conn: conn, scope: scope} do
      recurring_event_fixture(scope, %{"title" => "Whole Series Event"})

      {:ok, view, _html} = live(conn, ~p"/calendar")
      assert render(view) =~ "Whole Series Event"

      today = Date.utc_today()
      date_str = Date.to_iso8601(%{today | day: 1})
      view |> element("[phx-click='select_date'][phx-value-date='#{date_str}']") |> render_click()
      view |> element("[phx-click='show_recurrence_modal_delete']") |> render_click()
      view |> element("[phx-click='recurrence_delete_series']") |> render_click()

      refute render(view) =~ "Whole Series Event"
    end

    test "recurrence sub-fields appear when repeat type is not none", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/calendar")

      view |> element("button[phx-click='new_event']") |> render_click()

      # Initially sub-fields hidden (recurrence_type = "none")
      refute render(view) =~ "Repeat every"

      today = Date.utc_today()
      starts_at = "#{today.year}-#{String.pad_leading(to_string(today.month), 2, "0")}-20T18:00"

      view
      |> form("form", event: %{title: "Test", starts_at: starts_at, recurrence_type: "daily"})
      |> render_change()

      assert render(view) =~ "Repeat every"
    end
  end

  describe "links" do
    setup :register_and_log_in_user

    test "link UI not shown for new event form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/calendar")
      view |> element("button[phx-click='new_event']") |> render_click()
      refute render(view) =~ "Linked Grocery Lists"
    end

    test "link UI shown when editing existing event", %{conn: conn, scope: scope} do
      event = event_fixture(scope)
      grocery_list_fixture(scope, %{"name" => "Party Shopping"})

      {:ok, view, _html} = live(conn, ~p"/calendar")

      date_str = DateTime.to_date(event.starts_at) |> Date.to_iso8601()
      view |> element("[phx-click='select_date'][phx-value-date='#{date_str}']") |> render_click()
      view |> element("[phx-click='edit_event'][phx-value-id='#{event.id}']") |> render_click()

      assert render(view) =~ "Linked Grocery Lists"
      assert render(view) =~ "Party Shopping"
    end

    test "can toggle grocery list link", %{conn: conn, scope: scope} do
      event = event_fixture(scope)
      list = grocery_list_fixture(scope, %{"name" => "Party Shopping"})

      {:ok, view, _html} = live(conn, ~p"/calendar")

      date_str = DateTime.to_date(event.starts_at) |> Date.to_iso8601()
      view |> element("[phx-click='select_date'][phx-value-date='#{date_str}']") |> render_click()
      view |> element("[phx-click='edit_event'][phx-value-id='#{event.id}']") |> render_click()

      view
      |> element("[phx-click='toggle_grocery_link'][phx-value-list_id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "checked"
    end

    test "can link and unlink a budget transaction", %{conn: conn, scope: scope} do
      event = event_fixture(scope)
      transaction = transaction_fixture(scope, %{"description" => "Party Supplies"})

      {:ok, view, _html} = live(conn, ~p"/calendar")

      date_str = DateTime.to_date(event.starts_at) |> Date.to_iso8601()
      view |> element("[phx-click='select_date'][phx-value-date='#{date_str}']") |> render_click()
      view |> element("[phx-click='edit_event'][phx-value-id='#{event.id}']") |> render_click()

      assert render(view) =~ "Party Supplies"

      view
      |> form("form[phx-submit='toggle_transaction_link']", %{transaction_id: transaction.id})
      |> render_submit()

      # After linking, the transaction appears as a removable badge chip
      assert render(view) =~
               "phx-value-transaction_id=\"#{transaction.id}\""

      view
      |> element(
        "[phx-click='toggle_transaction_link'][phx-value-transaction_id='#{transaction.id}']"
      )
      |> render_click()

      # After unlinking, the badge button is gone (transaction moves back to dropdown)
      refute view
             |> element(
               "[phx-click='toggle_transaction_link'][phx-value-transaction_id='#{transaction.id}']"
             )
             |> has_element?()
    end
  end
end
