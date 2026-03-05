defmodule Hearth.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  Carries both the current user and their household, ensuring all
  context functions can scope queries by household_id.
  """

  alias Hearth.Accounts.User

  defstruct user: nil, household: nil

  @doc """
  Creates a scope for the given user, including their household.

  The user must have the household association preloaded.
  Returns nil if no user is given.
  """
  def for_user(%User{household: %Ecto.Association.NotLoaded{}} = _user) do
    raise "User must have household preloaded to create a scope"
  end

  def for_user(%User{} = user) do
    %__MODULE__{user: user, household: user.household}
  end

  def for_user(nil), do: nil
end
