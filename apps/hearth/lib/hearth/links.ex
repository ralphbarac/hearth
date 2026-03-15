defmodule Hearth.Links do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias Hearth.Links.Link

  def list_links_for(%Scope{household: household}, type, id) do
    Link
    |> where([l], l.household_id == ^household.id)
    |> where(
      [l],
      (l.source_type == ^type and l.source_id == ^id) or
        (l.target_type == ^type and l.target_id == ^id)
    )
    |> Repo.all()
  end

  def get_linked_ids(%Scope{} = scope, my_type, my_id, other_type) do
    scope
    |> list_links_for(my_type, my_id)
    |> Enum.flat_map(fn link ->
      cond do
        link.source_type == my_type and link.source_id == my_id and
            link.target_type == other_type ->
          [link.target_id]

        link.target_type == my_type and link.target_id == my_id and
            link.source_type == other_type ->
          [link.source_id]

        true ->
          []
      end
    end)
  end

  def get_link(%Scope{household: household}, source_type, source_id, target_type, target_id) do
    Link
    |> where([l], l.household_id == ^household.id)
    |> where([l], l.source_type == ^source_type and l.source_id == ^source_id)
    |> where([l], l.target_type == ^target_type and l.target_id == ^target_id)
    |> Repo.one()
  end

  def create_link(
        %Scope{household: household, user: user},
        source_type,
        source_id,
        target_type,
        target_id,
        metadata \\ %{}
      ) do
    %Link{}
    |> Link.changeset(%{
      source_type: source_type,
      source_id: source_id,
      target_type: target_type,
      target_id: target_id,
      metadata: metadata,
      household_id: household.id,
      created_by_id: user.id
    })
    |> Repo.insert()
  end

  def delete_link(%Scope{household: household}, %Link{} = link) do
    if link.household_id == household.id do
      Repo.delete(link)
    else
      {:error, :unauthorized}
    end
  end

  def toggle_link(%Scope{} = scope, source_type, source_id, target_type, target_id) do
    case get_link(scope, source_type, source_id, target_type, target_id) do
      nil -> create_link(scope, source_type, source_id, target_type, target_id)
      link -> delete_link(scope, link)
    end
  end
end
