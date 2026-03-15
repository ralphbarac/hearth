defmodule HearthDocuments.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "documents" do
    field :name, :string
    field :category, :string
    field :document_number, :string
    field :expiry_date, :date
    field :location_hint, :string
    field :notes, :string

    belongs_to :household, Hearth.Households.Household
    belongs_to :created_by, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:name, :category, :document_number, :expiry_date, :location_hint, :notes,
                    :household_id, :created_by_id])
    |> validate_required([:name, :household_id])
    |> validate_length(:name, max: 200)
    |> validate_length(:category, max: 100)
    |> validate_length(:document_number, max: 100)
    |> validate_length(:location_hint, max: 300)
  end
end
