defmodule Hearth.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :category, :string
      add :document_number, :string
      add :expiry_date, :date
      add :location_hint, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:household_id])
    create index(:documents, [:household_id, :expiry_date])
  end
end
