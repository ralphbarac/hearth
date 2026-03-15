defmodule HearthDocuments.DocumentsTest do
  use HearthDocuments.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthDocuments.DocumentsFixtures

  alias HearthDocuments.Documents
  alias HearthDocuments.Document

  setup do
    scope = user_scope_fixture()
    {:ok, scope: scope}
  end

  describe "list_documents/1" do
    test "returns all documents for household", %{scope: scope} do
      doc = document_fixture(scope)
      assert Enum.any?(Documents.list_documents(scope), &(&1.id == doc.id))
    end

    test "does not return docs from other households" do
      other = user_scope_fixture()
      doc = document_fixture(other)
      scope = user_scope_fixture()
      refute Enum.any?(Documents.list_documents(scope), &(&1.id == doc.id))
    end
  end

  describe "create_document/2" do
    test "creates document with valid attrs", %{scope: scope} do
      attrs = valid_document_attributes(%{"name" => "Passport", "category" => "Identity"})
      assert {:ok, %Document{} = doc} = Documents.create_document(scope, attrs)
      assert doc.name == "Passport"
      assert doc.category == "Identity"
    end

    test "returns error on missing name", %{scope: scope} do
      assert {:error, changeset} = Documents.create_document(scope, %{})
      assert %{name: [_ | _]} = errors_on(changeset)
    end
  end

  describe "list_expiring_soon/2" do
    test "returns docs with expiry within 90 days", %{scope: scope} do
      soon = document_fixture(scope, %{"expiry_date" => Date.add(Date.utc_today(), 30)})
      _far = document_fixture(scope, %{"expiry_date" => Date.add(Date.utc_today(), 200)})
      _none = document_fixture(scope)

      results = Documents.list_expiring_soon(scope)
      assert Enum.any?(results, &(&1.id == soon.id))
      assert length(results) == 1
    end

    test "includes already expired docs", %{scope: scope} do
      expired = document_fixture(scope, %{"expiry_date" => Date.add(Date.utc_today(), -5)})
      results = Documents.list_expiring_soon(scope)
      assert Enum.any?(results, &(&1.id == expired.id))
    end
  end

  describe "update_document/3" do
    test "updates document", %{scope: scope} do
      doc = document_fixture(scope)
      assert {:ok, updated} = Documents.update_document(scope, doc, %{"name" => "Updated"})
      assert updated.name == "Updated"
    end
  end

  describe "delete_document/2" do
    test "deletes document", %{scope: scope} do
      doc = document_fixture(scope)
      assert {:ok, _} = Documents.delete_document(scope, doc)
      assert Documents.list_documents(scope) == []
    end
  end
end
