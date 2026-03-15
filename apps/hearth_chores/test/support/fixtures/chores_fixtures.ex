defmodule HearthChores.ChoresFixtures do
  import Hearth.AccountsFixtures

  alias HearthChores.Chores

  def valid_chore_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Chore #{System.unique_integer([:positive])}",
      "frequency" => "weekly",
      "next_due_date" => Date.to_string(Date.utc_today())
    })
  end

  def chore_fixture(scope \\ user_scope_fixture(), attrs \\ %{}) do
    {:ok, chore} = Chores.create_chore(scope, valid_chore_attributes(attrs))
    chore
  end
end
