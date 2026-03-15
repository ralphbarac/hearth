defmodule Hearth.Repo.Migrations.CreateBills do
  use Ecto.Migration

  def change do
    create table(:bills, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :category_id, references(:budget_categories, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :amount, :integer, null: false
      add :frequency, :string, null: false
      add :next_due_date, :date, null: false
      add :notes, :text
      add :is_active, :boolean, default: true, null: false
      add :auto_create_transaction, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:bills, [:household_id])
    create index(:bills, [:household_id, :next_due_date])
  end
end
