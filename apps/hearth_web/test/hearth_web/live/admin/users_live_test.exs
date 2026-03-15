defmodule HearthWeb.Admin.UsersLiveTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Hearth.AccountsFixtures

  alias Hearth.Accounts

  defp register_and_log_in_admin(%{conn: conn}) do
    admin = user_fixture(%{role: "admin"})
    scope = Hearth.Accounts.Scope.for_user(admin)
    %{conn: log_in_user(conn, admin), admin: admin, scope: scope}
  end

  describe "Admin users page (admin)" do
    setup :register_and_log_in_admin

    test "renders page with user table", %{conn: conn, admin: admin} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ "Manage Users"
      assert html =~ admin.username
    end

    test "shows all household members", %{conn: conn, scope: scope, admin: admin} do
      member = user_fixture(%{household: scope.household})
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ admin.username
      assert html =~ member.username
    end

    test "shows New Member button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ "New Member"
    end

    test "opens new member form on button click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      view |> element("button", "+ New Member") |> render_click()
      assert render(view) =~ "Create Member"
    end

    test "closes form on cancel click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      view |> element("button", "+ New Member") |> render_click()
      view |> element("button", "Cancel") |> render_click()
      refute render(view) =~ "Create Member"
    end

    test "creates new member with valid attrs", %{conn: conn, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      view |> element("button", "+ New Member") |> render_click()

      new_username = unique_username()

      view
      |> form("form[phx-submit='create_member']",
        user: %{
          username: new_username,
          email: unique_user_email(),
          password: valid_user_password(),
          password_confirmation: valid_user_password(),
          role: "adult"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ new_username
      refute html =~ "Create Member"

      users = Accounts.list_household_users(scope)
      assert Enum.any?(users, &(&1.username == new_username))
    end

    test "shows validation error on blank submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      view |> element("button", "+ New Member") |> render_click()

      view
      |> form("form[phx-submit='create_member']", user: %{username: "", email: "", password: ""})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows error when password confirmation does not match", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")
      view |> element("button", "+ New Member") |> render_click()

      view
      |> form("form[phx-submit='create_member']",
        user: %{
          username: unique_username(),
          email: unique_user_email(),
          password: valid_user_password(),
          password_confirmation: "wrong_password_xyz"
        }
      )
      |> render_submit()

      assert render(view) =~ "does not match password"
    end

    test "saves user features and shows confirmation", %{conn: conn, scope: scope} do
      member = user_fixture(%{household: scope.household})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element("#user-features-#{member.id}")
      |> render_submit(%{"user_id" => member.id})

      assert render(view) =~ "Updated access for #{member.username}"
    end

    test "updates user role", %{conn: conn, scope: scope} do
      member = user_fixture(%{household: scope.household})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element("form[phx-change='update_role'][phx-value-user-id='#{member.id}']")
      |> render_change(%{"role" => "child"})

      updated = Accounts.get_user!(member.id)
      assert updated.role == "child"
    end

    test "deletes a member", %{conn: conn, scope: scope} do
      member = user_fixture(%{household: scope.household})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert render(view) =~ member.username

      view
      |> element("[phx-click='delete_user'][phx-value-user-id='#{member.id}']")
      |> render_click()

      refute render(view) =~ member.username
    end

    test "cannot delete self", %{conn: conn, admin: admin} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      refute view
             |> element("[phx-click='delete_user'][phx-value-user-id='#{admin.id}']")
             |> has_element?()
    end
  end

  describe "Admin users page (non-admin)" do
    setup :register_and_log_in_user

    test "redirects to dashboard", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/admin/users")
    end
  end
end
