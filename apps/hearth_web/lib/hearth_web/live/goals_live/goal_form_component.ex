defmodule HearthWeb.GoalsLive.GoalFormComponent do
  use HearthWeb, :live_component

  alias HearthBudget.SavingGoals
  alias HearthBudget.SavingGoal

  @impl true
  def update(%{goal: goal, scope: scope} = _assigns, socket) do
    initial_attrs =
      if goal.id,
        do: %{"target_amount_input" => format_amount_input(goal.target_amount)},
        else: %{}

    changeset = SavingGoal.changeset(goal, initial_attrs)

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:goal, goal)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"saving_goal" => params}, socket) do
    changeset =
      socket.assigns.goal
      |> SavingGoal.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"saving_goal" => params}, socket) do
    save_goal(socket, socket.assigns.goal.id, params)
  end

  defp save_goal(socket, nil, params) do
    case SavingGoals.create_goal(socket.assigns.scope, params) do
      {:ok, goal} ->
        send(self(), {__MODULE__, :saved, goal})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_goal(socket, _id, params) do
    case SavingGoals.update_goal(socket.assigns.scope, socket.assigns.goal, params) do
      {:ok, goal} ->
        send(self(), {__MODULE__, :saved, goal})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "saving_goal"))
  end

  defp format_amount_input(nil), do: ""

  defp format_amount_input(cents) when is_integer(cents) do
    :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Goal Name" />
        <.input
          field={@form[:target_amount_input]}
          type="number"
          label="Target Amount"
          step="0.01"
          min="0.01"
        />
        <.input field={@form[:target_date]} type="date" label="Target Date (optional)" />
        <.input field={@form[:notes]} type="textarea" label="Notes (optional)" />
        <div class="mt-4">
          <.button type="submit" variant="primary" phx-disable-with="Saving...">
            Save Goal
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
