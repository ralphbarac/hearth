defmodule HearthChores.Chore do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @frequencies ~w(once daily weekly biweekly monthly)
  @colors ~w(blue green amber rose purple slate)

  schema "chores" do
    field :name, :string
    field :description, :string
    field :frequency, :string, default: "weekly"
    field :next_due_date, :date
    field :is_active, :boolean, default: true
    field :color, :string, default: "slate"

    belongs_to :household, Hearth.Households.Household
    belongs_to :created_by, Hearth.Accounts.User
    belongs_to :assigned_to, Hearth.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(chore, attrs) do
    chore
    |> cast(attrs, [:name, :description, :frequency, :next_due_date, :is_active, :color,
                    :household_id, :created_by_id, :assigned_to_id])
    |> validate_required([:name, :frequency, :next_due_date, :household_id])
    |> validate_length(:name, max: 200)
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_inclusion(:color, @colors)
  end

  def frequencies, do: @frequencies
  def colors, do: @colors
end
