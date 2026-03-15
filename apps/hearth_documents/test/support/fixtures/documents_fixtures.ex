defmodule HearthDocuments.DocumentsFixtures do
  import Hearth.AccountsFixtures

  alias HearthDocuments.Documents

  def valid_document_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Document #{System.unique_integer([:positive])}"
    })
  end

  def document_fixture(scope \\ user_scope_fixture(), attrs \\ %{}) do
    {:ok, document} = Documents.create_document(scope, valid_document_attributes(attrs))
    document
  end
end
