defmodule Hearth.Repo.Migrations.CreateSavingGoals do
  use Ecto.Migration

  def change do
    create table(:saving_goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :target_amount, :integer, null: false
      add :target_date, :date
      add :notes, :text
      add :is_complete, :boolean, default: false, null: false

      add :household_id,
          references(:households, type: :binary_id, on_delete: :delete_all),
          null: false

      add :created_by_id,
          references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:saving_goals, [:household_id])
  end
end
