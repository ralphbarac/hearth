defmodule HearthWeb.BudgetLive.TransactionFormComponent do
  use HearthWeb, :live_component

  alias HearthBudget.Categories
  alias HearthBudget.Transactions
  alias HearthBudget.Transaction

  @impl true
  def update(%{transaction: transaction, scope: scope} = _assigns, socket) do
    initial_attrs =
      if transaction.id,
        do: %{"amount_input" => format_amount_input(transaction.amount)},
        else: %{}

    changeset = Transaction.changeset(transaction, initial_attrs)

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:transaction, transaction)
     |> assign(:categories, Categories.list_categories(scope))
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"transaction" => params}, socket) do
    changeset =
      socket.assigns.transaction
      |> Transaction.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"transaction" => params}, socket) do
    save_transaction(socket, socket.assigns.transaction.id, params)
  end

  defp save_transaction(socket, nil, params) do
    case Transactions.create_transaction(socket.assigns.scope, params) do
      {:ok, transaction} ->
        send(self(), {__MODULE__, :saved, transaction})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_transaction(socket, _id, params) do
    case Transactions.update_transaction(socket.assigns.scope, socket.assigns.transaction, params) do
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

  defp format_amount_input(nil), do: ""

  defp format_amount_input(cents) when is_integer(cents) do
    :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:description]} type="text" label="Description" />
        <.input field={@form[:amount_input]} type="number" label="Amount" step="0.01" min="0.01" />
        <.input
          field={@form[:type]}
          type="select"
          label="Type"
          options={[Income: "income", Expense: "expense"]}
        />
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
            Save Transaction
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
