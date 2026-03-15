defmodule Hearth.Repo.Migrations.AddFeaturesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :features, :map, default: %{}
    end
  end
end
