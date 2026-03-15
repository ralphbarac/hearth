defmodule Hearth.Links.Link do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "links" do
    field :source_type, :string
    field :source_id, :binary_id
    field :target_type, :string
    field :target_id, :binary_id
    field :metadata, :map, default: %{}

    belongs_to :household, Hearth.Households.Household
    belongs_to :created_by, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [
      :source_type,
      :source_id,
      :target_type,
      :target_id,
      :metadata,
      :household_id,
      :created_by_id
    ])
    |> validate_required([
      :source_type,
      :source_id,
      :target_type,
      :target_id,
      :household_id,
      :created_by_id
    ])
    |> unique_constraint(
      [:source_type, :source_id, :target_type, :target_id],
      name: :links_household_source_target_unique
    )
  end
end
