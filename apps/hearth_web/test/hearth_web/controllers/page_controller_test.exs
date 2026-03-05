defmodule HearthWeb.PageControllerTest do
  use HearthWeb.ConnCase

  test "GET / redirects to setup on first run", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/setup"
  end

  test "GET / redirects to login when users exist but not logged in", %{conn: conn} do
    Hearth.AccountsFixtures.user_fixture()
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/users/log-in"
  end

  test "GET / redirects to dashboard when logged in", %{conn: conn} do
    user = Hearth.AccountsFixtures.user_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/")
    assert redirected_to(conn) == "/dashboard"
  end
end
