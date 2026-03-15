defmodule Hearth.Repo.Migrations.CreateChores do
  use Ecto.Migration

  def change do
    create table(:chores, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :assigned_to_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :description, :text
      add :frequency, :string, null: false
      add :next_due_date, :date, null: false
      add :is_active, :boolean, default: true
      add :color, :string, default: "slate"

      timestamps(type: :utc_datetime)
    end

    create index(:chores, [:household_id])
    create index(:chores, [:household_id, :next_due_date])
    create index(:chores, [:assigned_to_id])
  end
end
