defmodule HearthWeb.DocumentsLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.DocumentsFixtures

  describe "Documents page" do
    setup :register_and_log_in_user

    test "redirects when feature disabled", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/documents")
    end
  end

  describe "Documents page (feature enabled)" do
    setup do
      scope = Hearth.AccountsFixtures.user_scope_fixture()
      {:ok, household} = Hearth.Households.update_features(scope.household, %{"documents" => true})
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
      {:ok, _view, html} = live(conn, ~p"/documents")
      assert html =~ "Document Vault"
      assert html =~ "Add Document"
    end

    test "shows empty state with no documents", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")
      assert html =~ "No documents yet"
    end

    test "shows existing documents", %{conn: conn, scope: scope} do
      doc = document_fixture(scope, %{"name" => "My Passport"})
      {:ok, _view, html} = live(conn, ~p"/documents")
      assert html =~ doc.name
    end

    test "opens document form via Add Document button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")
      view |> element("button", "Add Document") |> render_click()
      assert render(view) =~ "New Document"
    end

    test "creates document via form submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")
      view |> element("button", "Add Document") |> render_click()

      view
      |> form("form", document: %{name: "Car Insurance"})
      |> render_submit()

      assert render(view) =~ "Car Insurance"
    end

    test "validates blank document name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")
      view |> element("button", "Add Document") |> render_click()

      view
      |> form("form", document: %{name: ""})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows expiry warning banner for expiring docs", %{conn: conn, scope: scope} do
      document_fixture(scope, %{
        "name" => "Soon to Expire",
        "expiry_date" => Date.add(Date.utc_today(), 30)
      })

      {:ok, _view, html} = live(conn, ~p"/documents")
      assert html =~ "expiring or expired"
    end

    test "shows badge-error for expired doc", %{conn: conn, scope: scope} do
      document_fixture(scope, %{
        "name" => "Expired Doc",
        "expiry_date" => Date.add(Date.utc_today(), -5)
      })

      {:ok, _view, html} = live(conn, ~p"/documents")
      assert html =~ "badge-error"
    end

    test "deletes document", %{conn: conn, scope: scope} do
      doc = document_fixture(scope, %{"name" => "Delete Me"})
      {:ok, view, _html} = live(conn, ~p"/documents")
      assert render(view) =~ "Delete Me"

      view
      |> element("[phx-click='delete_document'][phx-value-id='#{doc.id}']")
      |> render_click()

      refute render(view) =~ "Delete Me"
    end
  end
end
