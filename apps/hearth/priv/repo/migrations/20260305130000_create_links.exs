defmodule Hearth.Repo.Migrations.CreateLinks do
  use Ecto.Migration

  def change do
    create table(:links, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :source_type, :string, null: false
      add :source_id, :binary_id, null: false
      add :target_type, :string, null: false
      add :target_id, :binary_id, null: false
      add :metadata, :map, default: %{}

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :links,
             [:household_id, :source_type, :source_id, :target_type, :target_id],
             name: :links_household_source_target_unique
           )

    create index(:links, [:household_id, :source_type, :source_id])
    create index(:links, [:household_id, :target_type, :target_id])
  end
end
