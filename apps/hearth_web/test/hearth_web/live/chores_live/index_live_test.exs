defmodule HearthWeb.ChoresLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.ChoresFixtures

  describe "Chores page" do
    setup :register_and_log_in_user

    test "redirects when feature disabled", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/chores")
    end
  end

  describe "Chores page (feature enabled)" do
    setup do
      scope = Hearth.AccountsFixtures.user_scope_fixture()
      {:ok, household} = Hearth.Households.update_features(scope.household, %{"chores" => true})
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
      {:ok, _view, html} = live(conn, ~p"/chores")
      assert html =~ "Chore Board"
      assert html =~ "Add Chore"
    end

    test "shows empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/chores")
      assert html =~ "No chores yet"
    end

    test "shows existing chores", %{conn: conn, scope: scope} do
      chore = chore_fixture(scope, %{"name" => "Vacuum living room"})
      {:ok, _view, html} = live(conn, ~p"/chores")
      assert html =~ chore.name
    end

    test "opens chore form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/chores")
      view |> element("button", "Add Chore") |> render_click()
      assert render(view) =~ "New Chore"
    end

    test "creates chore via form submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/chores")
      view |> element("button", "Add Chore") |> render_click()

      view
      |> form("form", chore: %{name: "Mow lawn", next_due_date: Date.to_string(Date.utc_today())})
      |> render_submit()

      assert render(view) =~ "Mow lawn"
    end

    test "completes a chore", %{conn: conn, scope: scope} do
      today = Date.utc_today()
      chore = chore_fixture(scope, %{"name" => "Daily Task", "frequency" => "daily", "next_due_date" => Date.to_string(today)})

      {:ok, view, _html} = live(conn, ~p"/chores")
      assert render(view) =~ "Daily Task"

      view
      |> element("[phx-click='complete_chore'][phx-value-id='#{chore.id}']")
      |> render_click()

      assert render(view) =~ "marked as complete"
    end

    test "deletes chore", %{conn: conn, scope: scope} do
      chore = chore_fixture(scope, %{"name" => "Delete Me"})
      {:ok, view, _html} = live(conn, ~p"/chores")
      assert render(view) =~ "Delete Me"

      view
      |> element("[phx-click='delete_chore'][phx-value-id='#{chore.id}']")
      |> render_click()

      refute render(view) =~ "Delete Me"
    end

    test "validates blank chore name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/chores")
      view |> element("button", "Add Chore") |> render_click()

      view
      |> form("form", chore: %{name: "", next_due_date: Date.to_string(Date.utc_today())})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end
  end
end
