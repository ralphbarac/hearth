defmodule Hearth.Households do
  @moduledoc """
  The Households context.
  """

  alias Hearth.Repo
  alias Hearth.Households.Household

  @doc """
  Returns true if no households exist (first-run state).
  """
  def first_run? do
    not Repo.exists?(Household)
  end

  @doc """
  Creates a household.
  """
  def create_household(attrs) do
    %Household{}
    |> Household.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a household by ID.
  """
  def get_household!(id), do: Repo.get!(Household, id)

  @doc """
  Updates a household.
  """
  def update_household(%Household{} = household, attrs) do
    household
    |> Household.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking household changes.
  """
  def change_household(%Household{} = household, attrs \\ %{}) do
    Household.changeset(household, attrs)
  end
end
