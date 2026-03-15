defmodule Hearth.Repo.Migrations.CreateCalendarTables do
  use Ecto.Migration

  def change do
    create table(:visibility_groups, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :color, :string, default: "blue"
      add :is_default, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:visibility_groups, [:household_id])

    create table(:calendar_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :description, :text
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime
      add :all_day, :boolean, default: false
      add :color, :string, default: "blue"
      add :location, :string
      add :recurrence_rule, :string

      timestamps(type: :utc_datetime)
    end

    create index(:calendar_events, [:household_id])
    create index(:calendar_events, [:household_id, :starts_at])

    create table(:event_visibility_groups, primary_key: false) do
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all),
        null: false

      add :group_id, references(:visibility_groups, type: :binary_id, on_delete: :delete_all),
        null: false
    end

    create unique_index(:event_visibility_groups, [:event_id, :group_id])

    create table(:visibility_group_members, primary_key: false) do
      add :group_id, references(:visibility_groups, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:visibility_group_members, [:group_id, :user_id])
  end
end
