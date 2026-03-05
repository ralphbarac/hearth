defmodule HearthWeb.SetupController do
  use HearthWeb, :controller

  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Households

  def new(conn, _params) do
    if Households.first_run?() do
      changeset = Accounts.change_user_registration(%User{})
      render(conn, :new, changeset: changeset)
    else
      conn
      |> put_flash(:info, "Setup has already been completed.")
      |> redirect(to: ~p"/")
    end
  end

  def create(conn, %{"user" => user_params, "household" => household_params}) do
    if not Households.first_run?() do
      conn
      |> put_flash(:error, "Setup has already been completed.")
      |> redirect(to: ~p"/")
    else
      case Accounts.setup_first_household(household_params, user_params) do
        {:ok, %{user: user}} ->
          conn
          |> put_flash(:info, "Welcome to Hearth! Your household has been created.")
          |> HearthWeb.UserAuth.log_in_user(user)

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, :new, changeset: changeset)

        {:error, _reason} ->
          changeset = Accounts.change_user_registration(%User{})

          conn
          |> put_flash(:error, "Something went wrong. Please try again.")
          |> render(:new, changeset: changeset)
      end
    end
  end
end
