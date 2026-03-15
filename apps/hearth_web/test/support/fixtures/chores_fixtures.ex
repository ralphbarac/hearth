defmodule HearthWeb.ChoresFixtures do
  alias HearthChores.Chores

  def valid_chore_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Chore #{System.unique_integer([:positive])}",
      "frequency" => "weekly",
      "next_due_date" => Date.to_string(Date.utc_today())
    })
  end

  def chore_fixture(scope, attrs \\ %{}) do
    {:ok, chore} = Chores.create_chore(scope, valid_chore_attributes(attrs))
    chore
  end
end
