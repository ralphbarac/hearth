defmodule Hearth.Repo.Migrations.CreateMaintenanceTables do
  use Ecto.Migration

  def change do
    create table(:maintenance_items, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :description, :text
      add :category, :string
      add :interval_days, :integer, null: false
      add :next_due_date, :date, null: false
      add :notes, :text
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:maintenance_items, [:household_id])
    create index(:maintenance_items, [:household_id, :next_due_date])

    create table(:maintenance_records, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :item_id,
          references(:maintenance_items, type: :binary_id, on_delete: :delete_all),
          null: false

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :performed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :performed_on, :date, null: false
      add :notes, :text
      add :cost_cents, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:maintenance_records, [:item_id])
    create index(:maintenance_records, [:household_id])
  end
end
