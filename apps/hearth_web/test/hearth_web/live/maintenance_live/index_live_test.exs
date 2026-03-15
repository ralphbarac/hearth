defmodule HearthWeb.MaintenanceLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.MaintenanceFixtures

  describe "Maintenance page" do
    setup :register_and_log_in_user

    test "redirects when feature disabled", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/maintenance")
    end
  end

  describe "Maintenance page (feature enabled)" do
    setup do
      scope = Hearth.AccountsFixtures.user_scope_fixture()
      {:ok, household} = Hearth.Households.update_features(scope.household, %{"maintenance" => true})
      scope = %{scope | household: household}

      user = scope.user
      token = Hearth.Accounts.generate_user_session_token(user)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, conn: conn, scope: scope}
    end

    test "renders page header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/maintenance")
      assert html =~ "Home Maintenance"
      assert html =~ "Add Item"
    end

    test "shows empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/maintenance")
      assert html =~ "No maintenance items yet"
    end

    test "shows existing items", %{conn: conn, scope: scope} do
      item = maintenance_item_fixture(scope, %{"name" => "HVAC Filter"})
      {:ok, _view, html} = live(conn, ~p"/maintenance")
      assert html =~ item.name
    end

    test "opens item form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/maintenance")
      view |> element("button", "Add Item") |> render_click()
      assert render(view) =~ "New Item"
    end

    test "creates item via form submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/maintenance")
      view |> element("button", "Add Item") |> render_click()

      view
      |> form("form", maintenance_item: %{
        name: "Water Filter",
        interval_days: 90,
        next_due_date: Date.to_string(Date.utc_today())
      })
      |> render_submit()

      assert render(view) =~ "Water Filter"
    end

    test "validates missing required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/maintenance")
      view |> element("button", "Add Item") |> render_click()

      view
      |> form("form", maintenance_item: %{name: "", interval_days: 30, next_due_date: Date.to_string(Date.utc_today())})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "opens log modal", %{conn: conn, scope: scope} do
      item = maintenance_item_fixture(scope, %{"name" => "Oil Change"})
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      view
      |> element("[phx-click='show_log_modal'][phx-value-id='#{item.id}']")
      |> render_click()

      assert render(view) =~ "Log Maintenance: Oil Change"
    end

    test "logs maintenance and closes modal", %{conn: conn, scope: scope} do
      item = maintenance_item_fixture(scope, %{"name" => "Oil Change", "interval_days" => 90})
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      view
      |> element("[phx-click='show_log_modal'][phx-value-id='#{item.id}']")
      |> render_click()

      view
      |> form("form[phx-submit='save_log']", maintenance_record: %{
        performed_on: Date.to_string(Date.utc_today())
      })
      |> render_submit()

      assert render(view) =~ "Maintenance logged"
      refute render(view) =~ "Log Maintenance: Oil Change"
    end

    test "shows history for item", %{conn: conn, scope: scope} do
      item = maintenance_item_fixture(scope, %{"name" => "Oil Change", "interval_days" => 90})
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      view
      |> element("[phx-click='show_log_modal'][phx-value-id='#{item.id}']")
      |> render_click()

      view
      |> form("form[phx-submit='save_log']", maintenance_record: %{
        performed_on: Date.to_string(Date.utc_today())
      })
      |> render_submit()

      item = HearthMaintenance.MaintenanceItems.get_item!(scope, item.id)

      view
      |> element("[phx-click='show_history'][phx-value-id='#{item.id}']")
      |> render_click()

      assert render(view) =~ "History"
    end

    test "deletes item", %{conn: conn, scope: scope} do
      item = maintenance_item_fixture(scope, %{"name" => "Delete Me"})
      {:ok, view, _html} = live(conn, ~p"/maintenance")
      assert render(view) =~ "Delete Me"

      view
      |> element("[phx-click='delete_item'][phx-value-id='#{item.id}']")
      |> render_click()

      refute render(view) =~ "Delete Me"
    end
  end
end
