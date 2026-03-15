defmodule HearthWeb.GoalsLive.ContributionFormComponent do
  use HearthWeb, :live_component

  alias HearthBudget.Categories
  alias HearthBudget.SavingGoals
  alias HearthBudget.Transaction

  @impl true
  def update(%{goal: goal, scope: scope} = _assigns, socket) do
    categories = Categories.list_categories(scope)
    savings_category_id = find_savings_category_id(categories)

    initial_attrs =
      %{}
      |> maybe_put("category_id", savings_category_id)
      |> Map.put("date", Date.to_string(Date.utc_today()))

    changeset = Transaction.changeset(%Transaction{}, initial_attrs)

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:goal, goal)
     |> assign(:categories, categories)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"transaction" => params}, socket) do
    changeset =
      %Transaction{}
      |> Transaction.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"transaction" => params}, socket) do
    case SavingGoals.add_contribution(socket.assigns.scope, socket.assigns.goal, params) do
      {:ok, transaction} ->
        send(self(), {__MODULE__, :saved, transaction})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "transaction"))
  end

  defp find_savings_category_id(categories) do
    case Enum.find(categories, &(&1.name == "Savings")) do
      nil -> nil
      cat -> cat.id
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:amount_input]} type="number" label="Amount" step="0.01" min="0.01" />
        <.input field={@form[:description]} type="text" label="Description (optional)" />
        <.input field={@form[:date]} type="date" label="Date" />
        <.input
          field={@form[:category_id]}
          type="select"
          label="Category"
          options={category_options(@categories)}
          prompt="No category"
        />
        <div class="mt-4">
          <.button type="submit" variant="primary" phx-disable-with="Saving...">
            Add Contribution
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  defp category_options(categories) do
    Enum.map(categories, fn c -> {c.name, c.id} end)
  end
end
