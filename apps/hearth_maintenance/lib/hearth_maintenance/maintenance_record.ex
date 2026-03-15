defmodule HearthMaintenance.MaintenanceRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "maintenance_records" do
    field :performed_on, :date
    field :notes, :string
    field :cost_cents, :integer
    field :cost_input, :string, virtual: true

    belongs_to :item, HearthMaintenance.MaintenanceItem
    belongs_to :household, Hearth.Households.Household
    belongs_to :performed_by, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:performed_on, :notes, :cost_cents, :cost_input,
                    :item_id, :household_id, :performed_by_id])
    |> validate_required([:performed_on, :item_id, :household_id])
    |> convert_cost_input()
  end

  defp convert_cost_input(changeset) do
    case get_change(changeset, :cost_input) do
      nil ->
        changeset

      "" ->
        put_change(changeset, :cost_cents, nil)

      input ->
        case Float.parse(input) do
          {float, _} -> put_change(changeset, :cost_cents, round(float * 100))
          :error -> add_error(changeset, :cost_input, "must be a valid number")
        end
    end
  end
end
