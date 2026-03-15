defmodule HearthWeb.BillsLive.BillFormComponent do
  use HearthWeb, :live_component

  alias HearthBudget.Categories
  alias HearthBudget.Bills
  alias HearthBudget.Bill

  @impl true
  def update(%{bill: bill, scope: scope} = _assigns, socket) do
    initial_attrs =
      if bill.id, do: %{"amount_input" => format_amount_input(bill.amount)}, else: %{}

    changeset = Bill.changeset(bill, initial_attrs)

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:bill, bill)
     |> assign(:categories, Categories.list_categories(scope))
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"bill" => params}, socket) do
    changeset =
      socket.assigns.bill
      |> Bill.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"bill" => params}, socket) do
    save_bill(socket, socket.assigns.bill.id, params)
  end

  defp save_bill(socket, nil, params) do
    case Bills.create_bill(socket.assigns.scope, params) do
      {:ok, bill} ->
        send(self(), {__MODULE__, :saved, bill})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_bill(socket, _id, params) do
    case Bills.update_bill(socket.assigns.scope, socket.assigns.bill, params) do
      {:ok, bill} ->
        send(self(), {__MODULE__, :saved, bill})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "bill"))
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
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:amount_input]} type="number" label="Amount" step="0.01" min="0.01" />
        <.input
          field={@form[:type]}
          type="select"
          label="Type"
          options={[Expense: "expense", Income: "income"]}
        />
        <.input
          field={@form[:frequency]}
          type="select"
          label="Frequency"
          options={[Weekly: "weekly", "Bi-weekly": "bi_weekly", Monthly: "monthly", Quarterly: "quarterly", Yearly: "yearly"]}
        />
        <.input field={@form[:next_due_date]} type="date" label="Next Due Date" />
        <.input
          field={@form[:category_id]}
          type="select"
          label="Category"
          options={category_options(@categories)}
          prompt="No category"
        />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <.input field={@form[:is_active]} type="checkbox" label="Active" />
        <.input
          field={@form[:auto_create_transaction]}
          type="checkbox"
          label="Auto-create transaction on payment"
        />
        <div class="mt-4">
          <.button type="submit" variant="primary" phx-disable-with="Saving...">Save Bill</.button>
        </div>
      </.form>
    </div>
    """
  end

  defp category_options(categories) do
    Enum.map(categories, fn c -> {c.name, c.id} end)
  end
end
