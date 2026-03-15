defmodule HearthWeb.GoalsLive.Index do
  use HearthWeb, :live_view

  alias HearthBudget.SavingGoals
  alias HearthBudget.SavingGoal
  alias HearthBudget.Categories
  alias HearthWeb.GoalsLive.GoalFormComponent
  alias HearthWeb.GoalsLive.ContributionFormComponent
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "budget") do
      {:ok,
       socket
       |> put_flash(:error, "Budget is not enabled for your account.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: SavingGoals.subscribe(scope)

      Categories.ensure_defaults(scope)

      {:ok,
       socket
       |> assign(page_title: "Savings Goals", active_nav: :budget)
       |> assign(show_form: false)
       |> assign(form_mode: nil)
       |> assign(editing_goal: nil)
       |> load_goals()}
    end
  end

  @impl true
  def handle_event("new_goal", _params, socket) do
    {:noreply, assign(socket, show_form: true, form_mode: :goal, editing_goal: %SavingGoal{})}
  end

  def handle_event("edit_goal", %{"id" => id}, socket) do
    goal = SavingGoals.get_goal!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, form_mode: :goal, editing_goal: goal)}
  end

  def handle_event("contribute", %{"id" => id}, socket) do
    goal = SavingGoals.get_goal!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, form_mode: :contribution, editing_goal: goal)}
  end

  def handle_event("mark_complete", %{"id" => id}, socket) do
    goal = SavingGoals.get_goal!(socket.assigns.current_scope, id)
    {:ok, _} = SavingGoals.mark_complete(socket.assigns.current_scope, goal)

    {:noreply,
     socket
     |> put_flash(:info, "Goal marked as complete!")
     |> load_goals()}
  end

  def handle_event("delete_goal", %{"id" => id}, socket) do
    goal = SavingGoals.get_goal!(socket.assigns.current_scope, id)
    {:ok, _} = SavingGoals.delete_goal(socket.assigns.current_scope, goal)

    {:noreply,
     socket
     |> put_flash(:info, "Goal deleted.")
     |> load_goals()}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, form_mode: nil, editing_goal: nil)}
  end

  @impl true
  def handle_info({GoalFormComponent, :saved, _goal}, socket) do
    {:noreply,
     socket
     |> assign(show_form: false, form_mode: nil, editing_goal: nil)
     |> load_goals()}
  end

  def handle_info({ContributionFormComponent, :saved, _transaction}, socket) do
    {:noreply,
     socket
     |> assign(show_form: false, form_mode: nil, editing_goal: nil)
     |> load_goals()}
  end

  def handle_info({SavingGoals, _action, _goal}, socket) do
    {:noreply, load_goals(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Savings Goals
        <:actions>
          <.button phx-click="new_goal" variant="primary">Add Goal</.button>
        </:actions>
      </.header>

      <div class="tabs tabs-bordered mb-6 mt-4">
        <.link navigate={~p"/budget"} class="tab">Transactions</.link>
        <.link navigate={~p"/budget/goals"} class="tab tab-active">Goals</.link>
      </div>

      <div class="mt-2 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form && "hidden md:block"]}>
          <%= if @active_goals == [] and @completed_goals == [] do %>
            <.empty_state
              icon="hero-banknotes"
              message="No savings goals yet. Add one to get started!"
            />
          <% end %>

          <%= if @active_goals != [] do %>
            <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3">
              Active Goals
            </h2>
            <div class="space-y-4 mb-6">
              <%= for goal <- @active_goals do %>
                <div class="card bg-base-100 border border-base-200 shadow-sm">
                  <div class="card-body p-4">
                    <div class="flex items-start justify-between gap-3">
                      <div class="flex-1 min-w-0">
                        <p class="font-semibold text-lg truncate">{goal.name}</p>
                        <%= if goal.target_date do %>
                          <span class="badge badge-outline badge-sm mt-1">
                            Due {Calendar.strftime(goal.target_date, "%b %Y")}
                          </span>
                        <% end %>
                      </div>
                      <div class="flex gap-1 shrink-0">
                        <.button
                          phx-click="contribute"
                          phx-value-id={goal.id}
                          class="btn btn-ghost btn-xs text-success"
                        >
                          Contribute
                        </.button>
                        <.button
                          phx-click="edit_goal"
                          phx-value-id={goal.id}
                          class="btn btn-ghost btn-xs"
                        >
                          Edit
                        </.button>
                        <.button
                          phx-click="mark_complete"
                          phx-value-id={goal.id}
                          data-confirm="Mark this goal as complete?"
                          class="btn btn-ghost btn-xs"
                        >
                          Complete
                        </.button>
                        <.button
                          phx-click="delete_goal"
                          phx-value-id={goal.id}
                          data-confirm="Delete this goal?"
                          class="btn btn-ghost btn-xs text-error"
                        >
                          Delete
                        </.button>
                      </div>
                    </div>

                    <div class="mt-3">
                      <div class="flex justify-between text-sm mb-1">
                        <span class="text-base-content/70">
                          {format_amount(goal.current_amount || 0)} of {format_amount(
                            goal.target_amount
                          )} saved
                        </span>
                        <span class="font-medium">
                          {progress_percent(goal.current_amount, goal.target_amount)}%
                        </span>
                      </div>
                      <progress
                        class="progress progress-success w-full"
                        value={goal.current_amount || 0}
                        max={goal.target_amount}
                      >
                      </progress>
                      <p class="text-sm text-base-content/60 mt-1">
                        {format_amount(remaining_amount(goal.current_amount, goal.target_amount))} remaining
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @completed_goals != [] do %>
            <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3">
              Completed Goals
            </h2>
            <div class="space-y-4 opacity-70">
              <%= for goal <- @completed_goals do %>
                <div class="card bg-base-100 border border-base-200 shadow-sm">
                  <div class="card-body p-4">
                    <div class="flex items-start justify-between gap-3">
                      <div class="flex-1 min-w-0">
                        <p class="font-semibold text-lg truncate">{goal.name}</p>
                        <span class="badge badge-success badge-sm mt-1">Completed</span>
                      </div>
                      <div class="flex gap-1 shrink-0">
                        <.button
                          phx-click="delete_goal"
                          phx-value-id={goal.id}
                          data-confirm="Delete this goal?"
                          class="btn btn-ghost btn-xs text-error"
                        >
                          Delete
                        </.button>
                      </div>
                    </div>

                    <div class="mt-3">
                      <div class="flex justify-between text-sm mb-1">
                        <span class="text-base-content/70">
                          {format_amount(goal.current_amount || 0)} of {format_amount(
                            goal.target_amount
                          )} saved
                        </span>
                      </div>
                      <progress
                        class="progress progress-success w-full"
                        value={goal.current_amount || 0}
                        max={goal.target_amount}
                      >
                      </progress>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div :if={@show_form} class="w-full md:w-96 shrink-0">
          <div class="flex items-center gap-2 mb-4 md:hidden">
            <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Back">
              <.icon name="hero-arrow-left" class="size-4" />
            </.button>
            <span class="font-medium">{form_title(@form_mode, @editing_goal)}</span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">{form_title(@form_mode, @editing_goal)}</h3>
                <.button
                  phx-click="close_form"
                  class="btn btn-ghost btn-sm btn-circle"
                  aria-label="Close"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>

              <%= if @form_mode == :goal do %>
                <.live_component
                  module={GoalFormComponent}
                  id={(@editing_goal && @editing_goal.id) || "new"}
                  goal={@editing_goal}
                  scope={@current_scope}
                />
              <% end %>

              <%= if @form_mode == :contribution do %>
                <.live_component
                  module={ContributionFormComponent}
                  id={"contribution-#{@editing_goal.id}"}
                  goal={@editing_goal}
                  scope={@current_scope}
                />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_goals(socket) do
    goals = SavingGoals.list_goals(socket.assigns.current_scope)
    {active, completed} = Enum.split_with(goals, &(not &1.is_complete))
    assign(socket, active_goals: active, completed_goals: completed)
  end

  defp progress_percent(current, target) when is_integer(current) and target > 0 do
    min(round(current / target * 100), 100)
  end

  defp progress_percent(_, _), do: 0

  defp remaining_amount(current, target) when is_integer(current) do
    max(target - current, 0)
  end

  defp remaining_amount(_, target), do: target

  defp form_title(:goal, %SavingGoal{id: nil}), do: "New Goal"
  defp form_title(:goal, _goal), do: "Edit Goal"
  defp form_title(:contribution, goal), do: "Contribute to #{goal.name}"
  defp form_title(_, _), do: "Form"
end
