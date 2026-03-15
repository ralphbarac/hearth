defmodule HearthRecipes.Tags do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthRecipes.Tag

  def list_tags(%Scope{household: household}) do
    Tag
    |> where([t], t.household_id == ^household.id)
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  def create_tag(%Scope{household: household}, attrs) do
    %Tag{}
    |> Tag.changeset(Map.merge(attrs, %{"household_id" => household.id}))
    |> Repo.insert()
  end

  def change_tag(%Scope{}, %Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  def delete_tag(%Scope{}, %Tag{} = tag) do
    Repo.delete(tag)
  end

  def find_or_create_tag(%Scope{household: household} = scope, name) do
    case Repo.get_by(Tag, household_id: household.id, name: name) do
      %Tag{} = tag ->
        {:ok, tag}

      nil ->
        case create_tag(scope, %{"name" => name}) do
          {:ok, tag} -> {:ok, tag}
          {:error, _} -> {:ok, Repo.get_by!(Tag, household_id: household.id, name: name)}
        end
    end
  end
end
