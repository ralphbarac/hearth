defmodule HearthWeb.PageController do
  use HearthWeb, :controller

  alias Hearth.Households

  def home(conn, _params) do
    cond do
      Households.first_run?() ->
        redirect(conn, to: ~p"/setup")

      conn.assigns[:current_scope] ->
        redirect(conn, to: ~p"/dashboard")

      true ->
        redirect(conn, to: ~p"/users/log-in")
    end
  end
end
