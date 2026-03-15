defmodule Hearth.Repo.Migrations.CreateChoreCompletions do
  use Ecto.Migration

  def change do
    create table(:chore_completions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :chore_id, references(:chores, type: :binary_id, on_delete: :delete_all), null: false

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :completed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :completed_on, :date, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:chore_completions, [:chore_id])
    create index(:chore_completions, [:household_id])
  end
end
