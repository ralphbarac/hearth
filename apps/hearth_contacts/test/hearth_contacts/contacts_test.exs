defmodule HearthContacts.ContactsTest do
  use HearthContacts.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthContacts.ContactsFixtures

  alias HearthContacts.Contacts
  alias HearthContacts.Contact

  setup do
    scope = user_scope_fixture()
    {:ok, scope: scope}
  end

  describe "list_contacts/1" do
    test "returns all contacts for household", %{scope: scope} do
      contact = contact_fixture(scope)
      assert Enum.any?(Contacts.list_contacts(scope), &(&1.id == contact.id))
    end

    test "does not return contacts from other households" do
      other_scope = user_scope_fixture()
      contact = contact_fixture(other_scope)
      scope = user_scope_fixture()
      refute Enum.any?(Contacts.list_contacts(scope), &(&1.id == contact.id))
    end

    test "favorites sort first", %{scope: scope} do
      _regular = contact_fixture(scope, %{"name" => "Bob"})
      fav = contact_fixture(scope, %{"name" => "Alice", "is_favorite" => true})
      contacts = Contacts.list_contacts(scope)
      assert hd(contacts).id == fav.id
    end
  end

  describe "create_contact/2" do
    test "creates contact with valid attrs", %{scope: scope} do
      attrs = valid_contact_attributes(%{"name" => "Plumber Joe", "role" => "Plumber"})
      assert {:ok, %Contact{} = contact} = Contacts.create_contact(scope, attrs)
      assert contact.name == "Plumber Joe"
      assert contact.role == "Plumber"
      assert contact.household_id == scope.household.id
    end

    test "returns error on missing name", %{scope: scope} do
      assert {:error, changeset} = Contacts.create_contact(scope, %{})
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "validates email format", %{scope: scope} do
      attrs = valid_contact_attributes(%{"email" => "not-an-email"})
      assert {:error, changeset} = Contacts.create_contact(scope, attrs)
      assert %{email: [_ | _]} = errors_on(changeset)
    end
  end

  describe "update_contact/3" do
    test "updates contact", %{scope: scope} do
      contact = contact_fixture(scope)
      assert {:ok, updated} = Contacts.update_contact(scope, contact, %{"name" => "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "delete_contact/2" do
    test "deletes contact", %{scope: scope} do
      contact = contact_fixture(scope)
      assert {:ok, _} = Contacts.delete_contact(scope, contact)
      assert Contacts.list_contacts(scope) == []
    end
  end

  describe "toggle_favorite/2" do
    test "toggles is_favorite", %{scope: scope} do
      contact = contact_fixture(scope)
      assert {:ok, fav} = Contacts.toggle_favorite(scope, contact)
      assert fav.is_favorite == true
      assert {:ok, unfav} = Contacts.toggle_favorite(scope, fav)
      assert unfav.is_favorite == false
    end
  end

  describe "search_contacts/2" do
    test "filters by name", %{scope: scope} do
      contact_fixture(scope, %{"name" => "Doctor Smith"})
      contact_fixture(scope, %{"name" => "Plumber Joe"})
      results = Contacts.search_contacts(scope, "Doctor")
      assert length(results) == 1
      assert hd(results).name == "Doctor Smith"
    end
  end
end
