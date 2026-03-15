defmodule Hearth.Repo.Migrations.CreateRecipeTables do
  use Ecto.Migration

  def change do
    create table(:recipe_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:recipe_tags, [:household_id, :name])

    create table(:recipes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :text, null: false
      add :description, :text
      add :servings, :integer
      add :prep_time_minutes, :integer
      add :cook_time_minutes, :integer
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:recipes, [:household_id])

    create table(:recipes_to_tags, primary_key: false) do
      add :recipe_id, references(:recipes, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:recipe_tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:recipes_to_tags, [:recipe_id, :tag_id])

    create table(:recipe_ingredients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :recipe_id, references(:recipes, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :quantity, :text
      add :unit, :text
      add :position, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:recipe_ingredients, [:recipe_id])

    create table(:recipe_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :recipe_id, references(:recipes, type: :binary_id, on_delete: :delete_all), null: false
      add :step_number, :integer, null: false
      add :description, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:recipe_steps, [:recipe_id])
    create unique_index(:recipe_steps, [:recipe_id, :step_number])
  end
end
