defmodule Hearth.Repo.Migrations.AddMissingFkIndexes do
  use Ecto.Migration

  def change do
    create index(:calendar_events, [:created_by_id])
    create index(:grocery_lists, [:created_by_id])
    create index(:grocery_items, [:added_by_id])
    create index(:links, [:created_by_id])
    create index(:bills, [:created_by_id])
  end
end
