defmodule Hearth.Repo.Migrations.CreateGroceryTables do
  use Ecto.Migration

  def change do
    create table(:grocery_lists, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :notes, :text
      add :is_active, :boolean, default: true, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:grocery_lists, [:household_id])

    create table(:grocery_items, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :list_id, references(:grocery_lists, type: :binary_id, on_delete: :delete_all),
        null: false

      add :added_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :quantity, :string
      add :category, :string
      add :checked, :boolean, default: false, null: false
      add :position, :integer, default: 0, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:grocery_items, [:list_id])
  end
end
