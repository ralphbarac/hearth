defmodule HearthWeb.ContactsLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.ContactsFixtures

  describe "Contacts page" do
    setup :register_and_log_in_user

    test "redirects when feature disabled", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/contacts")
    end
  end

  describe "Contacts page (feature enabled)" do
    setup do
      scope = Hearth.AccountsFixtures.user_scope_fixture()
      {:ok, household} = Hearth.Households.update_features(scope.household, %{"contacts" => true})
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
      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "Contacts"
      assert html =~ "Add Contact"
    end

    test "shows empty state with no contacts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "No contacts yet"
    end

    test "shows existing contacts", %{conn: conn, scope: scope} do
      contact = contact_fixture(scope, %{"name" => "Dr. Smith"})
      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ contact.name
    end

    test "opens contact form via Add Contact button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contacts")
      view |> element("button", "Add Contact") |> render_click()
      assert render(view) =~ "New Contact"
    end

    test "creates contact via form submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contacts")
      view |> element("button", "Add Contact") |> render_click()

      view
      |> form("form", contact: %{name: "Plumber Joe"})
      |> render_submit()

      assert render(view) =~ "Plumber Joe"
    end

    test "validates blank contact name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contacts")
      view |> element("button", "Add Contact") |> render_click()

      view
      |> form("form", contact: %{name: ""})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "deletes contact", %{conn: conn, scope: scope} do
      contact = contact_fixture(scope, %{"name" => "Delete Me"})
      {:ok, view, _html} = live(conn, ~p"/contacts")
      assert render(view) =~ "Delete Me"

      view
      |> element("[phx-click='delete_contact'][phx-value-id='#{contact.id}']")
      |> render_click()

      refute render(view) =~ "Delete Me"
    end

    test "toggles favorite", %{conn: conn, scope: scope} do
      contact = contact_fixture(scope, %{"name" => "Bob"})
      {:ok, view, _html} = live(conn, ~p"/contacts")

      view
      |> element("[phx-click='toggle_favorite'][phx-value-id='#{contact.id}']")
      |> render_click()

      assert render(view) =~ "text-warning"
    end
  end
end
