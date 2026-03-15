defmodule HearthDocuments.Documents do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthDocuments.Document

  @pubsub Hearth.PubSub

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_documents(%Scope{household: household}) do
    Document
    |> where([d], d.household_id == ^household.id)
    |> order_by([d], asc: d.name)
    |> Repo.all()
  end

  def list_documents_by_category(%Scope{} = scope) do
    scope
    |> list_documents()
    |> Enum.group_by(&(&1.category || "Uncategorized"))
  end

  def list_expiring_soon(%Scope{household: household}, days \\ 90) do
    cutoff = Date.add(Date.utc_today(), days)

    Document
    |> where([d], d.household_id == ^household.id)
    |> where([d], not is_nil(d.expiry_date) and d.expiry_date <= ^cutoff)
    |> order_by([d], asc: d.expiry_date)
    |> Repo.all()
  end

  def get_document!(%Scope{household: household}, id) do
    Document
    |> where([d], d.household_id == ^household.id and d.id == ^id)
    |> Repo.one!()
  end

  def change_document(%Scope{}, %Document{} = document, attrs \\ %{}) do
    Document.changeset(document, attrs)
  end

  def create_document(%Scope{user: user, household: household}, attrs) do
    %Document{}
    |> Document.changeset(Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id}))
    |> Repo.insert()
    |> tap_broadcast(household.id, :created)
  end

  def update_document(%Scope{household: household}, %Document{} = document, attrs) do
    document
    |> Document.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(household.id, :updated)
  end

  def delete_document(%Scope{household: household}, %Document{} = document) do
    Repo.delete(document)
    |> tap_broadcast(household.id, :deleted)
  end

  defp topic(household_id), do: "household:#{household_id}:documents"

  defp tap_broadcast({:ok, document} = result, household_id, action) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, document})
    result
  end

  defp tap_broadcast(error, _household_id, _action), do: error
end
