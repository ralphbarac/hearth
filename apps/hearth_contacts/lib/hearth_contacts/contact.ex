defmodule HearthContacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field :name, :string
    field :role, :string
    field :category, :string
    field :phone, :string
    field :email, :string
    field :address, :string
    field :notes, :string
    field :is_favorite, :boolean, default: false

    belongs_to :household, Hearth.Households.Household
    belongs_to :created_by, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :role, :category, :phone, :email, :address, :notes, :is_favorite,
                    :household_id, :created_by_id])
    |> validate_required([:name, :household_id])
    |> validate_length(:name, max: 200)
    |> validate_length(:phone, max: 50)
    |> validate_length(:email, max: 254)
    |> then(fn cs ->
      if get_field(cs, :email) not in [nil, ""] do
        validate_format(cs, :email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
      else
        cs
      end
    end)
  end
end
