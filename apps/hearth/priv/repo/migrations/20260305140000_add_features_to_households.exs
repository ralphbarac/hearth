defmodule Hearth.Repo.Migrations.AddFeaturesToHouseholds do
  use Ecto.Migration

  def change do
    alter table(:households) do
      add :features, :map, default: %{}, null: false
    end
  end
end
