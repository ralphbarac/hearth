defmodule HearthWeb.UserRegistrationController do
  use HearthWeb, :controller

  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Households

  def new(conn, _params) do
    if Households.first_run?() do
      redirect(conn, to: ~p"/setup")
    else
      changeset = Accounts.change_user_registration(%User{})
      render(conn, :new, changeset: changeset)
    end
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> HearthWeb.UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
