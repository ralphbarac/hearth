defmodule HearthBudget.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Hearth.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import HearthBudget.DataCase
    end
  end

  setup tags do
    Hearth.DataCase.setup_sandbox(tags)
    :ok
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
