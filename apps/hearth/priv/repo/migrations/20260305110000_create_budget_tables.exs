defmodule Hearth.Repo.Migrations.CreateBudgetTables do
  use Ecto.Migration

  def change do
    create table(:budget_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :icon, :string
      add :type, :string, null: false
      add :is_default, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:budget_categories, [:household_id])

    create table(:budget_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :category_id, references(:budget_categories, type: :binary_id, on_delete: :nilify_all)
      add :amount, :integer, null: false
      add :type, :string, null: false
      add :description, :string
      add :date, :date, null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:budget_transactions, [:household_id, :date])
  end
end
