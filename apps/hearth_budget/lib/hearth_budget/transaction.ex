defmodule HearthBudget.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(income expense)

  schema "budget_transactions" do
    field(:amount, :integer)
    field(:amount_input, :string, virtual: true)
    field(:type, :string)
    field(:description, :string)
    field(:date, :date)

    belongs_to(:household, Hearth.Households.Household)
    belongs_to(:category, HearthBudget.Category)
    belongs_to(:created_by, Hearth.Accounts.User)
    belongs_to(:saving_goal, HearthBudget.SavingGoal)

    timestamps(type: :utc_datetime)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :amount,
      :amount_input,
      :type,
      :description,
      :date,
      :household_id,
      :category_id,
      :created_by_id,
      :saving_goal_id
    ])
    |> convert_amount_input()
    |> validate_required([:amount, :type, :date, :household_id])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:type, @types)
    |> validate_length(:description, max: 500)
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
