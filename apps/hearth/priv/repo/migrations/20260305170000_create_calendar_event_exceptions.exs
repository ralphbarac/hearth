defmodule Hearth.Repo.Migrations.CreateCalendarEventExceptions do
  use Ecto.Migration

  def change do
    create table(:calendar_event_exceptions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all),
        null: false

      add :excluded_date, :date, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:calendar_event_exceptions, [:event_id, :excluded_date])
    create index(:calendar_event_exceptions, [:event_id])
  end
end
