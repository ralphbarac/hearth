defmodule Hearth.Repo.Migrations.AddRecurrenceToCalendarEvents do
  use Ecto.Migration

  def change do
    alter table(:calendar_events) do
      add :recurrence_type, :string, default: "none", null: false
      add :recurrence_interval, :integer, default: 1, null: false
      add :recurrence_until, :date
      add :recurrence_count, :integer

      add :recurrence_parent_id,
          references(:calendar_events, type: :binary_id, on_delete: :delete_all)
    end

    create index(:calendar_events, [:household_id, :recurrence_type])
  end
end
