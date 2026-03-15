defmodule Hearth.Repo.Migrations.AddTypeToBills do
  use Ecto.Migration

  def change do
    alter table(:bills) do
      add :type, :string, null: false, default: "expense"
    end
  end
end
