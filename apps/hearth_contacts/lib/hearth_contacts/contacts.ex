defmodule HearthContacts.Contacts do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthContacts.Contact

  @pubsub Hearth.PubSub

  def subscribe(%Scope{household: household}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(household.id))
  end

  def list_contacts(%Scope{household: household}) do
    Contact
    |> where([c], c.household_id == ^household.id)
    |> order_by([c], [desc: c.is_favorite, asc: c.name])
    |> Repo.all()
  end

  def list_contacts_by_category(%Scope{} = scope) do
    scope
    |> list_contacts()
    |> Enum.group_by(&(&1.category || "Uncategorized"))
  end

  def search_contacts(%Scope{household: household}, query) do
    pattern = "%#{query}%"

    Contact
    |> where([c], c.household_id == ^household.id)
    |> where([c], ilike(c.name, ^pattern) or ilike(c.role, ^pattern) or ilike(c.category, ^pattern))
    |> order_by([c], [desc: c.is_favorite, asc: c.name])
    |> Repo.all()
  end

  def get_contact!(%Scope{household: household}, id) do
    Contact
    |> where([c], c.household_id == ^household.id and c.id == ^id)
    |> Repo.one!()
  end

  def change_contact(%Scope{}, %Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end

  def create_contact(%Scope{user: user, household: household}, attrs) do
    %Contact{}
    |> Contact.changeset(Map.merge(attrs, %{"household_id" => household.id, "created_by_id" => user.id}))
    |> Repo.insert()
    |> tap_broadcast(household.id, :created)
  end

  def update_contact(%Scope{household: household}, %Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast(household.id, :updated)
  end

  def delete_contact(%Scope{household: household}, %Contact{} = contact) do
    Repo.delete(contact)
    |> tap_broadcast(household.id, :deleted)
  end

  def toggle_favorite(%Scope{} = scope, %Contact{} = contact) do
    update_contact(scope, contact, %{"is_favorite" => !contact.is_favorite})
  end

  defp topic(household_id), do: "household:#{household_id}:contacts"

  defp tap_broadcast({:ok, contact} = result, household_id, action) do
    Phoenix.PubSub.broadcast(@pubsub, topic(household_id), {__MODULE__, action, contact})
    result
  end

  defp tap_broadcast(error, _household_id, _action), do: error
end
