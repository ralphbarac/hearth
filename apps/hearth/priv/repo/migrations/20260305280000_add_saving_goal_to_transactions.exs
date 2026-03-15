defmodule Hearth.Repo.Migrations.AddSavingGoalToTransactions do
  use Ecto.Migration

  def change do
    alter table(:budget_transactions) do
      add :saving_goal_id,
          references(:saving_goals, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:budget_transactions, [:saving_goal_id])
  end
end
