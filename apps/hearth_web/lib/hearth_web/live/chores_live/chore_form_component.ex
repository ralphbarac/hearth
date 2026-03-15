defmodule HearthWeb.ChoresLive.ChoreFormComponent do
  use HearthWeb, :live_component

  alias HearthChores.Chores

  @impl true
  def update(assigns, socket) do
    chore = assigns.chore
    changeset = Chores.change_chore(assigns.scope, chore)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(changeset, action: nil))}
  end

  @impl true
  def handle_event("validate", %{"chore" => params}, socket) do
    changeset = Chores.change_chore(socket.assigns.scope, socket.assigns.chore, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"chore" => params}, socket) do
    scope = socket.assigns.scope
    chore = socket.assigns.chore

    result =
      if chore.id do
        Chores.update_chore(scope, chore, params)
      else
        Chores.create_chore(scope, params)
      end

    case result do
      {:ok, saved} ->
        send(self(), {__MODULE__, :saved, saved})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="space-y-4">
          <.input field={@form[:name]} label="Name" placeholder="Chore name" required />
          <.input field={@form[:description]} label="Description" type="textarea" />
          <.input
            field={@form[:frequency]}
            label="Frequency"
            type="select"
            options={[
              {"Once", "once"},
              {"Daily", "daily"},
              {"Weekly", "weekly"},
              {"Biweekly", "biweekly"},
              {"Monthly", "monthly"}
            ]}
          />
          <.input field={@form[:next_due_date]} label="Next Due Date" type="date" required />
          <.input
            field={@form[:assigned_to_id]}
            label="Assigned To"
            type="select"
            options={[{"Unassigned", ""} | Enum.map(@household_users, &{&1.username || &1.email, &1.id})]}
          />
          <.input
            field={@form[:color]}
            label="Color"
            type="select"
            options={[
              {"Slate", "slate"},
              {"Blue", "blue"},
              {"Green", "green"},
              {"Amber", "amber"},
              {"Rose", "rose"},
              {"Purple", "purple"}
            ]}
          />
          <.input field={@form[:is_active]} label="Active" type="checkbox" />
        </div>
        <div class="flex gap-2 mt-6">
          <.button type="submit" variant="primary" class="flex-1">
            {if @chore && @chore.id, do: "Save Changes", else: "Add Chore"}
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
