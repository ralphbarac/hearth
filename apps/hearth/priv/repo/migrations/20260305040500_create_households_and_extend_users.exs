defmodule Hearth.Repo.Migrations.CreateHouseholdsAndExtendUsers do
  use Ecto.Migration

  def change do
    create table(:households, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    alter table(:users) do
      add :username, :string
      add :role, :string, null: false, default: "adult"
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end

    create unique_index(:users, [:username])
    create index(:users, [:household_id])

    # Backfill: set created_by_id on households after users exist
    alter table(:households) do
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
