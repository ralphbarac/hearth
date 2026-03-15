defmodule HearthBudget.SavingGoal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "saving_goals" do
    field :name, :string
    field :target_amount, :integer
    field :target_amount_input, :string, virtual: true
    field :target_date, :date
    field :notes, :string
    field :is_complete, :boolean, default: false
    field :current_amount, :integer, virtual: true

    belongs_to :household, Hearth.Households.Household
    belongs_to :created_by, Hearth.Accounts.User
    has_many :contributions, HearthBudget.Transaction, foreign_key: :saving_goal_id

    timestamps(type: :utc_datetime)
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [
      :name,
      :target_amount,
      :target_amount_input,
      :target_date,
      :notes,
      :is_complete,
      :household_id,
      :created_by_id
    ])
    |> convert_amount_input()
    |> validate_required([:name, :target_amount, :household_id])
    |> validate_number(:target_amount, greater_than: 0)
    |> validate_length(:name, max: 200)
  end

  defp convert_amount_input(changeset) do
    case get_change(changeset, :target_amount_input) do
      nil ->
        changeset

      "" ->
        changeset

      input when is_binary(input) ->
        case Float.parse(input) do
          {float, _} ->
            put_change(changeset, :target_amount, round(float * 100))

          :error ->
            add_error(changeset, :target_amount_input, "must be a valid number")
        end
    end
  end
end
