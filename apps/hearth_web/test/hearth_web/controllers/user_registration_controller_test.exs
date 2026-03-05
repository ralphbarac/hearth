defmodule HearthWeb.UserRegistrationControllerTest do
  use HearthWeb.ConnCase, async: true

  import Hearth.AccountsFixtures

  describe "GET /users/register" do
    test "redirects to setup on first run", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      assert redirected_to(conn) == "/setup"
    end

    test "renders registration page when household exists", %{conn: conn} do
      # Create a household first
      user_fixture()
      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)
      assert response =~ "Register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
