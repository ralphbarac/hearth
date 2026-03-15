defmodule HearthBudget.Categories do
  import Ecto.Query

  alias Hearth.Repo
  alias Hearth.Accounts.Scope
  alias HearthBudget.Category

  @default_categories [
    %{name: "Salary", icon: "💼", type: "income"},
    %{name: "Bills", icon: "📄", type: "expense"},
    %{name: "Dining Out", icon: "🍔", type: "expense"},
    %{name: "Entertainment", icon: "🎉", type: "expense"},
    %{name: "Groceries", icon: "🛒", type: "expense"},
    %{name: "Housing", icon: "🏠", type: "expense"},
    %{name: "Transport", icon: "🚗", type: "expense"},
    %{name: "Savings", icon: "🎯", type: "expense"}
  ]

  def list_categories(%Scope{household: household}) do
    Category
    |> where([c], c.household_id == ^household.id)
    |> order_by([c], asc: c.type, asc: c.name)
    |> Repo.all()
  end

  def ensure_defaults(%Scope{household: household}) do
    count =
      Category
      |> where([c], c.household_id == ^household.id)
      |> Repo.aggregate(:count)

    if count == 0 do
      for attrs <- @default_categories do
        %Category{}
        |> Category.changeset(Map.merge(attrs, %{is_default: true, household_id: household.id}))
        |> Repo.insert!()
      end
    end

    :ok
  end

  def change_category(%Scope{}, %Category{} = cat, attrs \\ %{}) do
    Category.changeset(cat, attrs)
  end

  def create_category(%Scope{household: household}, attrs) do
    %Category{}
    |> Category.changeset(Map.merge(attrs, %{"household_id" => household.id, "is_default" => false}))
    |> Repo.insert()
  end

  def delete_category(%Scope{household: household}, %Category{} = cat)
      when cat.household_id == household.id do
    Repo.delete(cat)
  end
end
