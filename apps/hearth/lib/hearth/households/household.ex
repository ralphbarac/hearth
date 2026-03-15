defmodule Hearth.Households.Household do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "households" do
    field :name, :string
    field :features, :map, default: %{}
    belongs_to :created_by, Hearth.Accounts.User
    has_many :users, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(household, attrs) do
    household
    |> cast(attrs, [:name, :features, :created_by_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
  end
end
