defmodule HearthContacts.ContactsFixtures do
  import Hearth.AccountsFixtures

  alias HearthContacts.Contacts

  def valid_contact_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Contact #{System.unique_integer([:positive])}"
    })
  end

  def contact_fixture(scope \\ user_scope_fixture(), attrs \\ %{}) do
    {:ok, contact} = Contacts.create_contact(scope, valid_contact_attributes(attrs))
    contact
  end
end
