defmodule Hearth.Repo.Migrations.CreateInventoryTables do
  use Ecto.Migration

  def change do
    create table(:inventory_items, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :text, null: false
      add :unit, :text
      add :quantity, :integer, null: false, default: 0
      add :min_quantity, :integer, null: false, default: 0
      add :category, :text
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:inventory_items, [:household_id])
  end
end
