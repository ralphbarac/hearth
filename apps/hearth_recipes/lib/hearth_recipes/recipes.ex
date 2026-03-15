defmodule HearthRecipes.Recipes do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthRecipes.{Recipe, RecipeIngredient, RecipeStep, Tag}

  @pubsub Hearth.PubSub
  @topic_prefix "household"
  @topic_suffix "recipes"

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_recipes(%Scope{household: household}) do
    Recipe
    |> where([r], r.household_id == ^household.id)
    |> order_by([r], asc: r.name)
    |> preload(:tags)
    |> Repo.all()
  end

  def list_recipes_with_ingredients(%Scope{household: household}) do
    ingredients_query = from(i in RecipeIngredient, order_by: [asc: i.position])

    Recipe
    |> where([r], r.household_id == ^household.id)
    |> order_by([r], asc: r.name)
    |> preload([:tags, ingredients: ^ingredients_query])
    |> Repo.all()
  end

  def list_recipes_by_tag(%Scope{household: household}, tag_id) do
    Recipe
    |> where([r], r.household_id == ^household.id)
    |> join(:inner, [r], t in assoc(r, :tags), on: t.id == ^tag_id)
    |> order_by([r], asc: r.name)
    |> preload(:tags)
    |> Repo.all()
  end

  def get_recipe!(%Scope{household: household}, id) do
    ingredients_query = from(i in RecipeIngredient, order_by: [asc: i.position])
    steps_query = from(s in RecipeStep, order_by: [asc: s.step_number])

    Recipe
    |> where([r], r.household_id == ^household.id and r.id == ^id)
    |> preload([:tags, ingredients: ^ingredients_query, steps: ^steps_query])
    |> Repo.one!()
  end

  def change_recipe(%Recipe{} = recipe, attrs \\ %{}) do
    Recipe.changeset(recipe, attrs)
  end

  def create_recipe(%Scope{user: user, household: household}, attrs) do
    %Recipe{}
    |> Recipe.changeset(
      Map.merge(attrs, %{
        "household_id" => household.id,
        "created_by_id" => user.id
      })
    )
    |> Repo.insert()
    |> tap_broadcast(:created, household.id)
  end

  def update_recipe(%Scope{household: household}, %Recipe{} = recipe, attrs) do
    recipe
    |> Recipe.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, household.id)
  end

  def delete_recipe(%Scope{household: household}, %Recipe{} = recipe) do
    Repo.delete(recipe)
    |> tap_broadcast(:deleted, household.id)
  end

  def set_tags(%Scope{household: household}, %Recipe{} = recipe, tag_ids) do
    tags = Repo.all(from t in Tag, where: t.id in ^tag_ids and t.household_id == ^household.id)
    recipe = Repo.preload(recipe, :tags)

    recipe
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, tags)
    |> Repo.update()
    |> tap_broadcast(:updated, household.id)
  end

  def add_ingredient(%Scope{household: household}, %Recipe{} = recipe, attrs) do
    max_position =
      RecipeIngredient
      |> where([i], i.recipe_id == ^recipe.id)
      |> select([i], max(i.position))
      |> Repo.one()

    position = (max_position || -1) + 1

    %RecipeIngredient{}
    |> RecipeIngredient.changeset(
      Map.merge(attrs, %{"recipe_id" => recipe.id, "position" => position})
    )
    |> Repo.insert()
    |> tap_broadcast(:updated, household.id)
  end

  def update_ingredient(%Scope{household: household}, %RecipeIngredient{} = ingredient, attrs) do
    ingredient
    |> RecipeIngredient.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, household.id)
  end

  def delete_ingredient(%Scope{household: household}, %RecipeIngredient{} = ingredient) do
    Repo.delete(ingredient)
    |> tap_broadcast(:deleted, household.id)
  end

  def add_step(%Scope{household: household}, %Recipe{} = recipe, attrs) do
    %RecipeStep{}
    |> RecipeStep.changeset(Map.merge(attrs, %{"recipe_id" => recipe.id}))
    |> Repo.insert()
    |> tap_broadcast(:updated, household.id)
  end

  def update_step(%Scope{household: household}, %RecipeStep{} = step, attrs) do
    step
    |> RecipeStep.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(:updated, household.id)
  end

  def delete_step(%Scope{household: household}, %RecipeStep{} = step) do
    Repo.delete(step)
    |> tap_broadcast(:deleted, household.id)
  end

  defp topic(household_id), do: "#{@topic_prefix}:#{household_id}:#{@topic_suffix}"

  defp tap_broadcast({:ok, item} = result, action, household_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, item})
    result
  end

  defp tap_broadcast(error, _action, _household_id), do: error
end
