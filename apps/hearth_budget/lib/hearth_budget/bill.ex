defmodule HearthBudget.Bill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(income expense)
  @frequencies ~w(weekly bi_weekly monthly quarterly yearly)

  schema "bills" do
    field(:name, :string)
    field(:amount, :integer)
    field(:amount_input, :string, virtual: true)
    field(:type, :string, default: "expense")
    field(:frequency, :string)
    field(:next_due_date, :date)
    field(:notes, :string)
    field(:is_active, :boolean, default: true)
    field(:auto_create_transaction, :boolean, default: false)

    belongs_to(:household, Hearth.Households.Household)
    belongs_to(:created_by, Hearth.Accounts.User)
    belongs_to(:category, HearthBudget.Category)

    timestamps(type: :utc_datetime)
  end

  def changeset(bill, attrs) do
    bill
    |> cast(attrs, [
      :name,
      :amount,
      :amount_input,
      :type,
      :frequency,
      :next_due_date,
      :notes,
      :is_active,
      :auto_create_transaction,
      :household_id,
      :created_by_id,
      :category_id
    ])
    |> convert_amount_input()
    |> validate_required([:name, :amount, :type, :frequency, :next_due_date, :household_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_number(:amount, greater_than: 0)
  end

  defp convert_amount_input(changeset) do
    case get_change(changeset, :amount_input) do
      nil ->
        changeset

      "" ->
        changeset

      input when is_binary(input) ->
        case Float.parse(input) do
          {float, _} ->
            put_change(changeset, :amount, round(float * 100))

          :error ->
            add_error(changeset, :amount_input, "must be a valid number")
        end
    end
  end
end
