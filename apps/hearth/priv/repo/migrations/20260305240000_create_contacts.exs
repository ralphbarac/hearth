defmodule Hearth.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :role, :string
      add :category, :string
      add :phone, :string
      add :email, :string
      add :address, :text
      add :notes, :text
      add :is_favorite, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:household_id])
    create index(:contacts, [:household_id, :category])
  end
end
