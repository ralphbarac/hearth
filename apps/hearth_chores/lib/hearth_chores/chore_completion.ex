defmodule HearthChores.ChoreCompletion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chore_completions" do
    field :completed_on, :date
    field :notes, :string

    belongs_to :chore, HearthChores.Chore
    belongs_to :household, Hearth.Households.Household
    belongs_to :completed_by, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(completion, attrs) do
    completion
    |> cast(attrs, [:completed_on, :notes, :chore_id, :household_id, :completed_by_id])
    |> validate_required([:completed_on, :chore_id, :household_id])
  end
end
