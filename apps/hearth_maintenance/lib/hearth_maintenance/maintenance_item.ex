defmodule HearthMaintenance.MaintenanceItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "maintenance_items" do
    field :name, :string
    field :description, :string
    field :category, :string
    field :interval_days, :integer
    field :next_due_date, :date
    field :notes, :string
    field :is_active, :boolean, default: true

    belongs_to :household, Hearth.Households.Household
    belongs_to :created_by, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :description, :category, :interval_days, :next_due_date, :notes,
                    :is_active, :household_id, :created_by_id])
    |> validate_required([:name, :interval_days, :next_due_date, :household_id])
    |> validate_length(:name, max: 200)
    |> validate_number(:interval_days, greater_than: 0)
  end
end
